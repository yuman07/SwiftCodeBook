//
//  AsyncSemaphoreTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/AsyncSemaphore.swift
//
//  AsyncSemaphore is an actor-based async counting semaphore:
//    - init(value: UInt)
//    - func wait() async                       (non-cancellable, classic semantics)
//    - func waitUnlessCancelled() async throws (throws CancellationError on cancel)
//    - nonisolated func signal()               (fire-and-forget: spawns a Task -> release())
//
//  IMPORTANT BEHAVIORAL NOTE used throughout these tests:
//  `signal()` is `nonisolated` and merely schedules a detached `Task { await release() }`.
//  Therefore a permit released by `signal()` becomes available *eventually*, not
//  synchronously. Tests must use proper async synchronization (continuations,
//  confirmation, task groups) and never assume an immediate effect, while also
//  never using sleeps for synchronization.
//
//  DETERMINISTIC ORDERING: to assert FIFO / queue-position behaviour we must control
//  enqueue order. `Task.yield()` alone does NOT guarantee a spawned task has reached
//  the actor's `waiters.append(...)` point, so we poll the actor's internal
//  `waiterCount` (a @testable seam) until a waiter is provably enqueued before
//  spawning the next, and we observe resume order by releasing one permit at a time.
//
//  STRICT CANCELLATION: `waitUnlessCancelled()` never consumes a permit when the task
//  is cancelled — it throws even if a permit is available (fast path) and hands a
//  permit back if it loses the race to `release()` while enqueued.
//

import Testing
@testable import SwiftCodeBook
import Foundation

@Suite(.timeLimit(.minutes(1))) struct AsyncSemaphoreTests {

    // MARK: - Test support helpers (private; nested to avoid module-wide collisions)

    /// A Sendable, actor-backed counter for asserting concurrency invariants
    /// (e.g. how many tasks are inside a critical section at once).
    private actor MaxCounter {
        private var current = 0
        private var maximum = 0
        private var total = 0

        func enter() {
            current += 1
            total += 1
            if current > maximum { maximum = current }
        }

        func leave() {
            current -= 1
        }

        var observedMax: Int { maximum }
        var totalEntries: Int { total }
        var currentlyInside: Int { current }
    }

    /// A Sendable, actor-backed ordered recorder for asserting FIFO behaviour.
    private actor OrderRecorder {
        private(set) var order: [Int] = []
        func record(_ value: Int) { order.append(value) }
    }

    /// A Sendable, actor-backed one-shot boolean flag.
    private actor BoolFlag {
        private(set) var value = false
        func set() { value = true }
    }

    /// Deterministically blocks until `sem` has at least `count` enqueued waiters,
    /// so callers can establish queue (enqueue) order == creation order. This polls
    /// the actor's real queue length rather than assuming `Task.yield()` scheduled a
    /// different task, so it is not timing-dependent.
    private func waitUntilEnqueued(_ sem: AsyncSemaphore, atLeast count: Int) async {
        while await sem.waiterCount < count {
            await Task.yield()
        }
    }

    // MARK: - init & basic acquire (happy path)

    @Test func waitAcquiresImmediatelyWhenPermitsAvailable() async {
        let sem = AsyncSemaphore(value: 1)
        // Should return promptly without blocking because value > 0.
        await sem.wait()
        #expect(Bool(true)) // reaching here means wait() returned
    }

    @Test func waitTwiceConsumesTwoPermits() async {
        let sem = AsyncSemaphore(value: 2)
        await sem.wait()
        await sem.wait()
        // Both acquired without blocking.
        #expect(Bool(true))
    }

    @Test(arguments: [UInt(1), 2, 3, 5, 10, 100])
    func canAcquireExactlyInitialValuePermitsWithoutBlocking(initial: UInt) async {
        let sem = AsyncSemaphore(value: initial)
        for _ in 0..<initial {
            await sem.wait()
        }
        // If we got here, exactly `initial` acquisitions succeeded without a signal.
        #expect(Bool(true))
    }

    // MARK: - blocking then signal releases

    @Test func waitBlocksUntilSignalWhenNoPermits() async {
        let sem = AsyncSemaphore(value: 0)

        await confirmation("waiter resumes after signal") { resumed in
            let waiter = Task {
                await sem.wait()
                resumed()
            }

            // Signal once; the enqueued (or about-to-enqueue) waiter must resume.
            sem.signal()
            // Await the waiter to ensure the confirmation fires before the block ends.
            await waiter.value
        }
    }

    @Test func signalBeforeWaitMakesPermitAvailable() async {
        let sem = AsyncSemaphore(value: 0)
        // Signal raises value to 1 (eventually). We then wait; once the released
        // permit lands, wait() returns. Even if wait() enqueues first, the signal's
        // release() will resume it.
        sem.signal()
        await sem.wait() // must eventually return
        #expect(Bool(true))
    }

    @Test func multipleSignalsReleaseMultipleWaiters() async {
        let sem = AsyncSemaphore(value: 0)
        let count = 50

        await confirmation("all waiters resume", expectedCount: count) { resumed in
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<count {
                    group.addTask {
                        await sem.wait()
                        resumed()
                    }
                }
                for _ in 0..<count {
                    sem.signal()
                }
                await group.waitForAll()
            }
        }
    }

    // MARK: - mutual exclusion invariant (value == 1 behaves like a lock)

    @Test func binarySemaphoreEnforcesMutualExclusion() async {
        let sem = AsyncSemaphore(value: 1)
        let counter = MaxCounter()
        let workers = 200

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<workers {
                group.addTask {
                    await sem.wait()
                    await counter.enter()
                    // Touch the actor to create interleaving opportunities.
                    await Task.yield()
                    await counter.leave()
                    sem.signal()
                }
            }
            await group.waitForAll()
        }

        let max = await counter.observedMax
        let total = await counter.totalEntries
        #expect(total == workers)
        // With a binary semaphore at most one task may be inside the section.
        #expect(max == 1)
    }

    @Test func boundedConcurrencyNeverExceedsPermitCount() async {
        let permits: UInt = 4
        let sem = AsyncSemaphore(value: permits)
        let counter = MaxCounter()
        let workers = 300

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<workers {
                group.addTask {
                    await sem.wait()
                    await counter.enter()
                    await Task.yield()
                    await counter.leave()
                    sem.signal()
                }
            }
            await group.waitForAll()
        }

        let max = await counter.observedMax
        let total = await counter.totalEntries
        #expect(total == workers)
        // Never more than `permits` tasks concurrently inside the critical section.
        #expect(max <= Int(permits))
        #expect(max >= 1)
    }

    // MARK: - FIFO ordering guarantee

    @Test func waitersAreResumedInFIFOOrder() async {
        // release() uses waiters.removeFirst(), so resume order is FIFO over enqueue
        // order. We make this deterministic two ways:
        //  (1) enqueue order == creation order, by confirming each waiter is actually
        //      enqueued (waiterCount) before spawning the next;
        //  (2) resume order is observed without a downstream race, by releasing one
        //      permit at a time and awaiting that waiter before the next signal.
        let sem = AsyncSemaphore(value: 0)
        let recorder = OrderRecorder()
        let n = 20

        var tasks: [Task<Void, Never>] = []
        for i in 0..<n {
            let t = Task {
                await sem.wait()
                await recorder.record(i)
            }
            tasks.append(t)
            await waitUntilEnqueued(sem, atLeast: i + 1)
        }

        for i in 0..<n {
            sem.signal()
            await tasks[i].value // exactly one waiter (the head == waiter i) resumes
        }

        let order = await recorder.order
        #expect(order.count == n)
        // FIFO: resumed in the same order they were enqueued.
        #expect(order == Array(0..<n))
    }

    // MARK: - waitUnlessCancelled happy path

    @Test func waitUnlessCancelledAcquiresImmediatelyWhenAvailable() async throws {
        let sem = AsyncSemaphore(value: 1)
        try await sem.waitUnlessCancelled()
        #expect(Bool(true))
    }

    @Test func waitUnlessCancelledResumesAfterSignal() async throws {
        let sem = AsyncSemaphore(value: 0)
        let waiter = Task {
            try await sem.waitUnlessCancelled()
        }
        sem.signal()
        try await waiter.value // must complete without throwing
        #expect(Bool(true))
    }

    @Test(arguments: [UInt(1), 2, 4, 8])
    func waitUnlessCancelledConsumesInitialPermits(initial: UInt) async throws {
        let sem = AsyncSemaphore(value: initial)
        for _ in 0..<initial {
            try await sem.waitUnlessCancelled()
        }
        #expect(Bool(true))
    }

    // MARK: - waitUnlessCancelled cancellation

    @Test func waitUnlessCancelledThrowsWhenCancelledWhileWaiting() async {
        let sem = AsyncSemaphore(value: 0)

        let waiter = Task {
            try await sem.waitUnlessCancelled()
        }
        // Ensure the task starts and reaches the enqueue point before cancelling.
        await Task.yield()
        await Task.yield()
        waiter.cancel()

        let result = await waiter.result
        switch result {
        case .success:
            // With value:0 and no signal, success is impossible under correct
            // semantics; surface any unexpected success.
            #expect(Bool(false), "Expected CancellationError but wait succeeded with no signal")
        case .failure(let error):
            #expect(error is CancellationError)
        }
    }

    @Test func waitUnlessCancelledThrowsWhenTaskAlreadyCancelled() async {
        let sem = AsyncSemaphore(value: 0)

        let waiter = Task {
            // Cancel self before awaiting: inside the continuation Task.isCancelled
            // is true, so it resumes throwing CancellationError immediately.
            try await sem.waitUnlessCancelled()
        }
        waiter.cancel()

        let result = await waiter.result
        switch result {
        case .success:
            #expect(Bool(false), "Expected CancellationError on pre-cancelled task")
        case .failure(let error):
            #expect(error is CancellationError)
        }
    }

    @Test func cancellationDoesNotConsumeAPermit() async throws {
        // Documented: "On cancellation the waiter is removed without consuming a permit."
        let sem = AsyncSemaphore(value: 0)

        // Start a waiter that will be cancelled.
        let cancelledWaiter = Task {
            try await sem.waitUnlessCancelled()
        }
        await Task.yield()
        await Task.yield()
        cancelledWaiter.cancel()
        // Drain its result (expected to throw).
        _ = await cancelledWaiter.result

        // Now a single signal should be enough to satisfy a fresh waiter,
        // proving the cancelled waiter did not consume the permit.
        let goodWaiter = Task {
            try await sem.waitUnlessCancelled()
        }
        await Task.yield()
        await Task.yield()
        sem.signal()
        try await goodWaiter.value
        #expect(Bool(true))
    }

    @Test func cancelledWaiterDoesNotStealPermitFromOtherWaiter() async throws {
        // If a permit is released and one waiter is cancelled, the permit must
        // go to the remaining waiter (or be retained), never lost.
        let sem = AsyncSemaphore(value: 0)

        let toCancel = Task { try await sem.waitUnlessCancelled() }
        await Task.yield()
        await Task.yield()

        let survivor = Task { try await sem.waitUnlessCancelled() }
        await Task.yield()
        await Task.yield()

        toCancel.cancel()
        _ = await toCancel.result

        // One signal should satisfy the survivor.
        sem.signal()
        try await survivor.value
        #expect(Bool(true))
    }

    // MARK: - mixed wait() and waitUnlessCancelled() interplay

    @Test func mixedWaitersAllResumeWithEnoughSignals() async throws {
        let sem = AsyncSemaphore(value: 0)
        let total = 40

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                group.addTask {
                    if i % 2 == 0 {
                        await sem.wait()
                    } else {
                        try await sem.waitUnlessCancelled()
                    }
                }
            }
            // Release everyone.
            for _ in 0..<total {
                sem.signal()
            }
            try await group.waitForAll()
        }
        #expect(Bool(true))
    }

    // MARK: - signal beyond capacity raises available permits

    @Test func extraSignalsIncreasePermitCount() async {
        // Starting at 0, signal 3 times -> value eventually 3 -> three waits succeed.
        let sem = AsyncSemaphore(value: 0)
        sem.signal()
        sem.signal()
        sem.signal()

        await confirmation("three waits succeed", expectedCount: 3) { acquired in
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<3 {
                    group.addTask {
                        await sem.wait()
                        acquired()
                    }
                }
                await group.waitForAll()
            }
        }
    }

    // MARK: - stress / large data, time-bounded

    @Test func highContentionThroughputProducerConsumer() async {
        // Many tasks each acquire+release once; with a small permit count this
        // exercises heavy waiter enqueue/dequeue churn. Assert no permits leak:
        // every task completes and the section bound holds.
        let permits: UInt = 8
        let sem = AsyncSemaphore(value: permits)
        let counter = MaxCounter()
        let workers = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<workers {
                group.addTask {
                    await sem.wait()
                    await counter.enter()
                    await counter.leave()
                    sem.signal()
                }
            }
            await group.waitForAll()
        }

        let total = await counter.totalEntries
        let max = await counter.observedMax
        let inside = await counter.currentlyInside
        #expect(total == workers)
        #expect(max <= Int(permits))
        #expect(inside == 0)
    }

    @Test func cancellationStormDoesNotCrashOrLeak() async throws {
        // Spawn many cancellable waiters with no permits, cancel them all,
        // then verify the semaphore is still usable and a fresh signal/wait works.
        let sem = AsyncSemaphore(value: 0)
        let n = 300

        var tasks: [Task<Void, Error>] = []
        for _ in 0..<n {
            tasks.append(Task { try await sem.waitUnlessCancelled() })
        }
        // Let them enqueue.
        await Task.yield()
        await Task.yield()
        for t in tasks { t.cancel() }
        // Drain results; each should fail with cancellation since no permits issued.
        for t in tasks {
            let r = await t.result
            if case .success = r {
                #expect(Bool(false), "No permits issued; cancelled waiter should not succeed")
            }
        }

        // Semaphore still functional afterwards.
        let fresh = Task { try await sem.waitUnlessCancelled() }
        await Task.yield()
        await Task.yield()
        sem.signal()
        try await fresh.value
        #expect(Bool(true))
    }

    // MARK: - nonisolated signal callable from sync context

    @Test func signalIsNonisolatedAndReturnsSynchronously() async {
        // signal() is nonisolated; calling it from a non-async context must compile
        // and return immediately. We just verify it can be invoked without await
        // and that a subsequent wait eventually succeeds.
        let sem = AsyncSemaphore(value: 0)
        func fireFromSync() { sem.signal() } // sync context proves nonisolated
        fireFromSync()
        await sem.wait()
        #expect(Bool(true))
    }

    // MARK: - value:0 with paired signal/wait round-trip

    @Test func signalWaitRoundTripRepeatedly() async {
        let sem = AsyncSemaphore(value: 0)
        let rounds = 100
        for _ in 0..<rounds {
            sem.signal()
            await sem.wait()
        }
        // Each signal eventually paired with a wait; reaching here means no deadlock.
        #expect(Bool(true))
    }

    // MARK: - wait() is non-cancellable (the distinguishing contract vs waitUnlessCancelled)

    @Test func waitIgnoresCancellationAndOnlyResumesOnSignal() async {
        // The whole reason wait() and waitUnlessCancelled() are separate: a task
        // suspended in wait() must resume ONLY on signal(), never because of
        // cancellation. The `Task<Void, Never>` type also compile-time-pins that
        // wait() does not throw, so a regression that made it throw would not build.
        let sem = AsyncSemaphore(value: 0)
        let flag = BoolFlag()

        let t: Task<Void, Never> = Task {
            await sem.wait()
            await flag.set()
        }
        await waitUntilEnqueued(sem, atLeast: 1)

        // Cancel and give cancellation ample opportunity to (wrongly) resume it.
        t.cancel()
        for _ in 0..<50 { await Task.yield() }

        // Still blocked: not resumed, still enqueued, flag unset.
        #expect(await flag.value == false)
        #expect(await sem.waiterCount == 1)

        // Only a signal releases it.
        sem.signal()
        await t.value
        #expect(await flag.value == true)
        #expect(await sem.waiterCount == 0)
    }

    // MARK: - waitUnlessCancelled strict cancellation semantics

    @Test func waitUnlessCancelledThrowsWhenCancelledEvenWithPermitAvailable() async throws {
        // Strict semantics: a cancelled task never acquires, even when a permit is
        // immediately available, and the permit must NOT be consumed.
        // We deterministically arrive "already cancelled" by parking the task in a
        // non-cancellable wait() on a gate, cancelling it there, then releasing it so
        // it reaches waitUnlessCancelled() with cancellation already pending.
        let gate = AsyncSemaphore(value: 0)
        let sem = AsyncSemaphore(value: 1)

        let t = Task {
            await gate.wait() // non-cancellable: stays parked until released
            try await sem.waitUnlessCancelled()
        }
        await waitUntilEnqueued(gate, atLeast: 1)

        t.cancel()      // cancel while parked at the gate
        gate.signal()   // now let it proceed into waitUnlessCancelled(), already cancelled

        switch await t.result {
        case .success:
            #expect(Bool(false), "Cancelled task must throw even with a permit available")
        case .failure(let error):
            #expect(error is CancellationError)
        }

        // The permit was not consumed: a fresh (non-cancelled) wait acquires it with no signal.
        try await sem.waitUnlessCancelled()
        #expect(Bool(true))
    }

    @Test func concurrentSignalAndCancelNeverDoubleResumesOrLosesPermit() async {
        // Race a single permit release against cancelling a waiter, many times. We do
        // NOT assume the cancelled waiter loses: signal() is issued before cancel(),
        // so release() may legitimately resume w1 before cancellation lands.
        //
        // What must hold regardless of interleaving:
        //   - no double-resume (a double resume traps and crashes the whole run);
        //   - the permit is never lost. If w1 did NOT acquire (cancelled before
        //     release reached it, or it handed the permit back), that permit must
        //     remain in the semaphore — proven by a second, never-cancelled waiter
        //     acquiring it WITHOUT a fresh signal. A lost permit would instead hang
        //     here, caught by the suite's time limit.
        let iterations = 500
        for _ in 0..<iterations {
            let sem = AsyncSemaphore(value: 0)
            let w1 = Task<Bool, Never> { (try? await sem.waitUnlessCancelled()) != nil }
            await waitUntilEnqueued(sem, atLeast: 1)

            sem.signal()  // exactly one permit
            w1.cancel()   // race release() vs cancelWaiter() on w1
            let acquired1 = await w1.value

            let w2 = Task<Bool, Never> { (try? await sem.waitUnlessCancelled()) != nil }
            if acquired1 {
                // w1 consumed the permit; w2 needs its own to finish.
                sem.signal()
            }
            // If w1 did not acquire, the conserved permit satisfies w2 with no new signal.
            let acquired2 = await w2.value
            #expect(acquired2)
        }
    }

    // MARK: - cancellation does not disturb FIFO delivery to survivors

    @Test func cancellingHeadWaiterDeliversPermitToNextInFIFO() async throws {
        // Cancelling the head-of-line waiter must not block delivery: the next
        // permit goes to the new head, in FIFO order.
        let sem = AsyncSemaphore(value: 0)
        let recorder = OrderRecorder()

        let head = Task { try await sem.waitUnlessCancelled() }
        await waitUntilEnqueued(sem, atLeast: 1)
        let mid = Task { try await sem.waitUnlessCancelled(); await recorder.record(1) }
        await waitUntilEnqueued(sem, atLeast: 2)
        let tail = Task { try await sem.waitUnlessCancelled(); await recorder.record(2) }
        await waitUntilEnqueued(sem, atLeast: 3)

        // Cancel the head and drain its cancellation BEFORE signalling.
        head.cancel()
        if case .success = await head.result {
            #expect(Bool(false), "Cancelled head waiter must not acquire")
        }

        sem.signal()
        try await mid.value
        #expect(await recorder.order == [1])

        sem.signal()
        try await tail.value
        #expect(await recorder.order == [1, 2])
    }

    @Test func mixedQueueWithMidCancellationPreservesOrderForSurvivors() async throws {
        // wait() and waitUnlessCancelled() share one FIFO queue. Cancelling a
        // cancellable waiter sitting BETWEEN two non-cancellable ones must remove it
        // without consuming a permit or reordering the survivors. The Task<Void, Never>
        // entries (A, C) also pin that wait() never throws when a neighbour cancels.
        let sem = AsyncSemaphore(value: 0)
        let recorder = OrderRecorder()

        let a: Task<Void, Never> = Task { await sem.wait(); await recorder.record(0) }
        await waitUntilEnqueued(sem, atLeast: 1)
        let b = Task { try await sem.waitUnlessCancelled(); await recorder.record(1) }
        await waitUntilEnqueued(sem, atLeast: 2)
        let c: Task<Void, Never> = Task { await sem.wait(); await recorder.record(2) }
        await waitUntilEnqueued(sem, atLeast: 3)
        let d = Task { try await sem.waitUnlessCancelled(); await recorder.record(3) }
        await waitUntilEnqueued(sem, atLeast: 4)

        // Cancel the middle cancellable waiter; drain before signalling.
        b.cancel()
        if case .success = await b.result {
            #expect(Bool(false), "Cancelled middle waiter must not acquire")
        }

        // Three permits satisfy A, C, D in FIFO order; B is excluded.
        sem.signal(); await a.value
        sem.signal(); await c.value
        sem.signal(); try await d.value
        #expect(await recorder.order == [0, 2, 3])
    }
}
