//
//  TaskToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/Task+Tools.swift
//  Covers the public `Task` extension:
//    - var toAnyCancellable: AnyCancellable
//        Produces an AnyCancellable whose cancellation cancels the underlying Task.
//    - func store(in cancelBag: CancelBag)
//        Stores the task's AnyCancellable in a CancelBag so that cancelAll() cancels it.
//
//  The extension is generic over Task<Success, Failure>; we exercise it across
//  several Success / Failure shapes and verify cancellation propagation, FIFO-agnostic
//  bulk cancellation via CancelBag, and concurrent storage safety.
//

import Testing
import Combine
import Foundation
@testable import SwiftCodeBook

@Suite struct TaskToolsTests {

    // MARK: - Helpers

    /// A one-shot, multi-waiter gate that suspends every `wait()` caller until `signal()`
    /// is called, then resumes them all. Critically this supports an UNBOUNDED number of
    /// concurrent waiters (the concurrency tests below park hundreds/thousands of tasks
    /// on it simultaneously); a single-continuation design would silently leak all but
    /// the last continuation and either trap ("CONTINUATION MISUSE: leaked") or hang.
    ///
    /// No `Task.sleep`/polling is used, so suspension/resume is fully deterministic.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var signaled = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                lock.lock()
                if signaled {
                    lock.unlock()
                    c.resume()
                } else {
                    waiters.append(c)
                    lock.unlock()
                }
            }
        }

        func signal() {
            lock.lock()
            if signaled {
                lock.unlock()
                return
            }
            signaled = true
            let pending = waiters
            waiters.removeAll()
            lock.unlock()
            for c in pending { c.resume() }
        }
    }

    /// A custom error used to distinguish "threw on its own" from "was cancelled".
    private struct SampleError: Error, Equatable { let code: Int }

    /// A trivial Sendable reference type for the reference-success shape.
    private final class RefBox: Sendable { let n: Int; init(_ n: Int) { self.n = n } }

    // MARK: - toAnyCancellable: identity / basic shape

    @Test
    func toAnyCancellableReturnsUsableCancellable() async {
        let task = Task<Int, Never> { 42 }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        let value = await task.value
        #expect(value == 42)
        // The task ran to completion without anyone cancelling it.
        #expect(!task.isCancelled)
    }

    @Test
    func eachAccessProducesDistinctCancellableInstances() async {
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }

        let c1 = task.toAnyCancellable
        let c2 = task.toAnyCancellable
        // Computed property creates a fresh AnyCancellable each time.
        #expect(c1 !== c2)

        // Either cancellable cancels the same underlying task.
        c1.cancel()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
        // Keep c2 alive across the await so its deinit isn't what causes cancellation.
        _ = c2
    }

    @Test
    func merelyReadingToAnyCancellableDoesNotCancel() async {
        // Accessing the property and KEEPING the reference must not cancel the task.
        let task = Task<Int, Never> { 7 }
        let cancellable = task.toAnyCancellable
        let value = await task.value
        #expect(value == 7)
        #expect(!task.isCancelled)
        _ = cancellable
    }

    // MARK: - toAnyCancellable: cancellation propagation

    @Test
    func cancellingTheCancellableCancelsTheTask() async {
        let gate = Gate()
        let task = Task<Void, Never> {
            await gate.wait()
        }
        let cancellable = task.toAnyCancellable

        #expect(!task.isCancelled)
        cancellable.cancel()
        // Let the suspended task observe cancellation and finish.
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancellableDeinitTriggersTaskCancellation() async {
        // AnyCancellable cancels on deinit; dropping the only reference must cancel the task.
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }

        do {
            let cancellable = task.toAnyCancellable
            #expect(!task.isCancelled)
            _ = cancellable
        } // cancellable deallocates here -> cancel()

        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancellationIsObservedAsThrownCancellationError() async {
        // For a throwing task whose body checks cancellation, cancelling the wrapper
        // should surface as a CancellationError when the body calls Task.checkCancellation.
        let gate = Gate()
        let task = Task<Int, Error> {
            await gate.wait()
            try Task.checkCancellation()
            return 1
        }
        let cancellable = task.toAnyCancellable
        cancellable.cancel()
        gate.signal()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(task.isCancelled)
    }

    @Test
    func cancelBeforeFirstSuspensionPointStillCancels() async {
        // Cancel the wrapper BEFORE the task ever reaches its first await. The task's
        // checkCancellation at the top must already see the cancelled flag.
        let started = Gate()
        // Block the test thread's continuation creation until we've cancelled, by
        // having the task wait on `started` which we never signal before cancelling.
        let task = Task<Int, Error> {
            await started.wait()
            try Task.checkCancellation()
            return 1
        }
        let cancellable = task.toAnyCancellable
        cancellable.cancel()
        #expect(task.isCancelled) // flag is visible immediately after cancel()
        started.signal()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test
    func notCancellingLetsTaskCompleteNormally() async throws {
        let task = Task<String, Error> {
            try Task.checkCancellation()
            return "done"
        }
        let cancellable = task.toAnyCancellable
        // Hold the cancellable for the whole lifetime; never cancel it.
        let value = try await task.value
        #expect(value == "done")
        #expect(!task.isCancelled)
        _ = cancellable // keep alive past the await
    }

    @Test
    func multipleCancelCallsAreIdempotent() async {
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        let cancellable = task.toAnyCancellable
        cancellable.cancel()
        cancellable.cancel()
        cancellable.cancel()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancellingOneOfTwoCancellablesCancelsTheSharedTask() async {
        // Two distinct cancellables wrapping the same task; cancelling EITHER must cancel
        // the shared underlying task, and the other being dropped afterward is harmless.
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        let c1 = task.toAnyCancellable
        let c2 = task.toAnyCancellable
        #expect(!task.isCancelled)
        c2.cancel()
        #expect(task.isCancelled)
        gate.signal()
        await task.value
        _ = c1
    }

    // MARK: - toAnyCancellable: various Success / Failure generic shapes

    @Test
    func worksForVoidSuccessNeverFailure() async {
        let task = Task<Void, Never> { }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        await task.value
        #expect(!task.isCancelled)
    }

    @Test
    func worksForReferenceTypeSuccess() async {
        let task = Task<RefBox, Never> { RefBox(7) }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        let box = await task.value
        #expect(box.n == 7)
        #expect(!task.isCancelled)
    }

    @Test
    func worksForThrowingTaskThatSucceeds() async throws {
        let task = Task<Int, Error> { 99 }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        let value = try await task.value
        #expect(value == 99)
        #expect(!task.isCancelled)
    }

    @Test
    func worksForThrowingTaskThatThrowsCustomError() async {
        let task = Task<Int, Error> { throw SampleError(code: 13) }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        await #expect(throws: SampleError(code: 13)) {
            try await task.value
        }
        // A task that throws on its own was not cancelled.
        #expect(!task.isCancelled)
    }

    @Test
    func worksForStringSuccessShape() async {
        let task = Task<String, Never> { "hello" }
        let cancellable = task.toAnyCancellable
        _ = cancellable
        let value = await task.value
        #expect(value == "hello")
        #expect(!task.isCancelled)
    }

    // MARK: - store(in:) basics

    @Test
    func storeKeepsTaskRunningUntilCancelAll() async {
        let bag = CancelBag()
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        task.store(in: bag)

        #expect(!task.isCancelled)
        bag.cancelAll()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancelAllCancelsAllStoredTasks() async {
        let bag = CancelBag()
        let gate = Gate()
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<50 {
            let t = Task<Void, Never> { await gate.wait() }
            t.store(in: bag)
            tasks.append(t)
        }
        for t in tasks { #expect(!t.isCancelled) }

        bag.cancelAll()
        gate.signal()
        for t in tasks {
            await t.value
            #expect(t.isCancelled)
        }
    }

    @Test
    func bagDeinitReleasesTokensAndCancelsStoredTasks() async {
        // CancelBag.deinit drops its strong references to the stored AnyCancellables.
        // When the bag holds the ONLY reference, that release fires AnyCancellable.deinit
        // -> cancel(). (The bag does not call cancel() itself; it relies on token deinit.)
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }

        do {
            let bag = CancelBag()
            task.store(in: bag)
            #expect(!task.isCancelled)
            _ = bag
        } // bag deinit -> tokens removed -> AnyCancellable deinit -> cancel()

        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func storingTasksOfDifferentGenericShapesInSameBag() async {
        let bag = CancelBag()
        let gate = Gate()
        let voidTask = Task<Void, Never> { await gate.wait() }
        let intTask = Task<Int, Error> { await gate.wait(); return 0 }
        let strTask = Task<String, Never> { await gate.wait(); return "x" }

        voidTask.store(in: bag)
        intTask.store(in: bag)
        strTask.store(in: bag)

        bag.cancelAll()
        gate.signal()

        await voidTask.value
        _ = try? await intTask.value
        _ = await strTask.value
        #expect(voidTask.isCancelled)
        #expect(intTask.isCancelled)
        #expect(strTask.isCancelled)
    }

    @Test
    func cancelAllOnEmptyBagIsHarmless() async {
        let bag = CancelBag()
        bag.cancelAll()
        bag.cancelAll()
        // After draining an empty bag, storing a fresh task must still work normally.
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        task.store(in: bag)
        #expect(!task.isCancelled)
        bag.cancelAll()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancelAllIsIdempotentAfterTasksCancelled() async {
        let bag = CancelBag()
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        task.store(in: bag)
        bag.cancelAll()
        bag.cancelAll() // second sweep: bag already emptied
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func cancellingAfterNaturalCompletionDoesNotChangeTheResult() async {
        // A task that finished naturally already produced its value. cancelAll() still
        // invokes Task.cancel() on the stored token; note that Task.cancel() sets the
        // cancellation flag UNCONDITIONALLY, so isCancelled flips to true even though
        // the task is already done. The contract that matters is that the *result* is
        // unaffected and nothing crashes.
        let bag = CancelBag()
        let task = Task<Int, Never> { 5 }
        task.store(in: bag)
        let value = await task.value
        #expect(value == 5)
        #expect(!task.isCancelled) // before cancel(): a finished, never-cancelled task
        // Cancelling after natural completion must not crash and must not alter the value.
        bag.cancelAll()
        let valueAfterCancel = await task.value
        #expect(valueAfterCancel == 5)
    }

    @Test
    func storingAnAlreadyCancelledTaskKeepsItCancelled() async {
        // Cancel the task first, then store it. The bag's later cancelAll() is a no-op
        // for it, and the task must remain cancelled throughout.
        let bag = CancelBag()
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        task.cancel()
        #expect(task.isCancelled)
        task.store(in: bag)
        bag.cancelAll()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func sameTaskStoredTwiceIsCancelledByCancelAll() async {
        // Storing the same task twice produces two distinct AnyCancellable tokens (each
        // toAnyCancellable access is fresh). Both land in the Set; cancelAll cancels.
        let bag = CancelBag()
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }
        task.store(in: bag)
        task.store(in: bag)
        #expect(!task.isCancelled)
        bag.cancelAll()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }

    @Test
    func largeButBoundedNumberOfTasksAllCancelled() async {
        // Bounded large fan-in into a single bag, cancelled in one sweep.
        let bag = CancelBag()
        let gate = Gate()
        let count = 2000
        var tasks: [Task<Void, Never>] = []
        tasks.reserveCapacity(count)
        for _ in 0..<count {
            let t = Task<Void, Never> { await gate.wait() }
            t.store(in: bag)
            tasks.append(t)
        }
        bag.cancelAll()
        gate.signal()
        var cancelledCount = 0
        for t in tasks {
            await t.value
            if t.isCancelled { cancelledCount += 1 }
        }
        #expect(cancelledCount == count)
    }

    // MARK: - Concurrency: hammer store(in:) on a shared CancelBag

    @Test
    func concurrentStoreAndCancelAllNoCrashAllCancelled() async {
        let bag = CancelBag()
        let gate = Gate()
        let count = 1000

        // Spawn many tasks concurrently, each storing itself in the shared bag.
        let created: [Task<Void, Never>] = await withTaskGroup(of: Task<Void, Never>.self) { group in
            for _ in 0..<count {
                group.addTask {
                    let t = Task<Void, Never> { await gate.wait() }
                    t.store(in: bag)
                    return t
                }
            }
            var acc: [Task<Void, Never>] = []
            acc.reserveCapacity(count)
            for await t in group {
                acc.append(t)
            }
            return acc
        }
        #expect(created.count == count)

        // Cancel everything and release all gated tasks.
        bag.cancelAll()
        gate.signal()

        var cancelledCount = 0
        for t in created {
            await t.value
            if t.isCancelled { cancelledCount += 1 }
        }
        #expect(cancelledCount == count)
    }

    @Test
    func concurrentToAnyCancellableAccessIsThreadSafe() async {
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }

        // Access the computed property from many tasks at once; each dropped cancellable
        // cancels the task on deinit. None of these should crash or data-race.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    let c = task.toAnyCancellable
                    _ = c // immediately drops -> cancels the task on deinit
                }
            }
            await group.waitForAll()
        }

        gate.signal()
        await task.value
        // At least one of the dropped cancellables must have cancelled the task.
        #expect(task.isCancelled)
    }

    @Test
    func concurrentCancelAllFromMultipleTasksIsSafe() async {
        let bag = CancelBag()
        let gate = Gate()
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<200 {
            let t = Task<Void, Never> { await gate.wait() }
            t.store(in: bag)
            tasks.append(t)
        }

        // Many concurrent cancelAll() invocations on the same bag.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { bag.cancelAll() }
            }
            await group.waitForAll()
        }

        gate.signal()
        for t in tasks {
            await t.value
            #expect(t.isCancelled)
        }
    }

    @Test
    func concurrentStoreWhileCancellingIsSafe() async {
        // Race storing new tasks against repeated cancelAll() sweeps on the same bag.
        // Then a final sweep guarantees every stored task ends cancelled. The only
        // contract being verified is "no crash / no data race"; the final cancelAll
        // makes the end state deterministic regardless of interleaving.
        let bag = CancelBag()
        let gate = Gate()
        let count = 500

        let created: [Task<Void, Never>] = await withTaskGroup(of: Task<Void, Never>?.self) { group in
            for _ in 0..<count {
                group.addTask {
                    let t = Task<Void, Never> { await gate.wait() }
                    t.store(in: bag)
                    return t
                }
            }
            // Concurrent cancelAll sweeps interleaved with stores above.
            for _ in 0..<count {
                group.addTask {
                    bag.cancelAll()
                    return nil
                }
            }
            var acc: [Task<Void, Never>] = []
            for await t in group {
                if let t { acc.append(t) }
            }
            return acc
        }
        #expect(created.count == count)

        bag.cancelAll() // final deterministic sweep
        gate.signal()
        var cancelledCount = 0
        for t in created {
            await t.value
            if t.isCancelled { cancelledCount += 1 }
        }
        #expect(cancelledCount == count)
    }

    // MARK: - Parameterized: a batch of independent tasks each cancelled via its own bag

    @Test(arguments: [0, 1, 2, 10, 100])
    func batchOfTasksEachCancelledByOwnBag(taskCount: Int) async {
        let gate = Gate()
        var bags: [CancelBag] = []
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<taskCount {
            let bag = CancelBag()
            let t = Task<Void, Never> { await gate.wait() }
            t.store(in: bag)
            bags.append(bag)
            tasks.append(t)
        }
        for bag in bags { bag.cancelAll() }
        gate.signal()
        for t in tasks {
            await t.value
            #expect(t.isCancelled)
        }
        #expect(tasks.count == taskCount)
        #expect(bags.count == taskCount)
    }

    // MARK: - store(in:) vs toAnyCancellable equivalence

    @Test
    func storeInBagIsEquivalentToManualCancellableStorage() async {
        // store(in:) is documented as toAnyCancellable.store(in: bag).
        // Verify the manual composition yields the same cancellation behaviour.
        let bag = CancelBag()
        let gate = Gate()
        let task = Task<Void, Never> { await gate.wait() }

        // Manual path:
        task.toAnyCancellable.store(in: bag)

        bag.cancelAll()
        gate.signal()
        await task.value
        #expect(task.isCancelled)
    }
}
