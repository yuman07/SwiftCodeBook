//
//  SerialTaskExecutorTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/SerialTaskExecutor.swift
//
//  Public surface under test:
//    - SerialTaskExecutor.init(priority:)
//    - SerialTaskExecutor.addTask(_:) -> AnyCancellable   (@discardableResult)
//    - SerialTaskExecutor.runTask<Success: Sendable>(_:) async throws -> Success
//    - SerialTaskExecutor.cancelAll()
//    - deinit behavior (indirect)
//
//  LazyTask is `private`, so it is exercised only indirectly through the
//  executor's public surface.
//

import Combine
import Foundation
import Testing
@testable import SwiftCodeBook

@Suite(.timeLimit(.minutes(1))) struct SerialTaskExecutorTests {

    // MARK: - Test helpers (private, nested to avoid module-wide name collisions)

    private enum OperationError: Error, Equatable {
        case failed(Int)
    }

    /// A thread-safe ordered recorder for observing task side effects.
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _values: [Int] = []

        func append(_ value: Int) {
            lock.lock()
            _values.append(value)
            lock.unlock()
        }

        var values: [Int] {
            lock.lock()
            defer { lock.unlock() }
            return _values
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _values.count
        }
    }

    /// A simple thread-safe boolean flag.
    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false

        func set() {
            lock.lock()
            _value = true
            lock.unlock()
        }

        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
    }

    /// A thread-safe counter that records how many times it was incremented.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = 0

        func increment() {
            lock.lock()
            _value += 1
            lock.unlock()
        }

        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
    }

    /// Tracks how many operations are simultaneously "active" and remembers the
    /// peak. For a correct serial executor the peak must be exactly 1.
    private final class OverlapDetector: @unchecked Sendable {
        private let lock = NSLock()
        private var active = 0
        private var maxActive = 0

        func enter() {
            lock.lock()
            active += 1
            maxActive = max(maxActive, active)
            lock.unlock()
        }

        func leave() {
            lock.lock()
            active -= 1
            lock.unlock()
        }

        var peak: Int {
            lock.lock()
            defer { lock.unlock() }
            return maxActive
        }
    }

    /// A thread-safe integer accumulator.
    private final class Accumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var _sum = 0

        func add(_ value: Int) {
            lock.lock()
            _sum += value
            lock.unlock()
        }

        var sum: Int {
            lock.lock()
            defer { lock.unlock() }
            return _sum
        }
    }

    /// A one-shot gate that can be awaited until opened, without polling/sleeping.
    /// Multiple waiters are supported. `open()` is idempotent.
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func open() {
            lock.lock()
            if isOpen {
                lock.unlock()
                return
            }
            isOpen = true
            let pending = waiters
            waiters.removeAll()
            lock.unlock()
            for w in pending { w.resume() }
        }

        func wait() async {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                lock.lock()
                if isOpen {
                    lock.unlock()
                    cont.resume()
                } else {
                    waiters.append(cont)
                    lock.unlock()
                }
            }
        }
    }

    // A bounded cooperative quiescence barrier: yields a fixed number of times so
    // any already-scheduled cooperative work has a chance to run. Used only for
    // negative assertions ("X must NOT have happened"); it never gates a positive
    // result, so it cannot introduce a hang or a false pass.
    private static func drainCooperatively(iterations: Int = 2_000) async {
        for _ in 0..<iterations { await Task.yield() }
    }

    // MARK: - Initialization

    @Test func inheritsPriorityWhenInitializedWithoutPriority() async {
        let expectedPriority = Task.currentPriority
        let executor = SerialTaskExecutor()
        let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
            executor.addTask {
                cont.resume(returning: Task.currentPriority)
            }
        }
        #expect(actualPriority == expectedPriority)
    }

    @Test(arguments: [
        TaskPriority.high,
        TaskPriority.medium,
        TaskPriority.low,
        TaskPriority.background,
        TaskPriority.utility,
        TaskPriority.userInitiated
    ])
    func runsTasksAtExplicitPriority(_ priority: TaskPriority) async {
        let executor = SerialTaskExecutor(priority: priority)
        let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
            executor.addTask {
                cont.resume(returning: Task.currentPriority)
            }
        }
        #expect(actualPriority == priority)
    }

    @Test func inheritsPriorityWhenInitializedWithNilPriority() async {
        let expectedPriority = Task.currentPriority
        let executor = SerialTaskExecutor(priority: nil)
        let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
            executor.addTask {
                cont.resume(returning: Task.currentPriority)
            }
        }
        #expect(actualPriority == expectedPriority)
    }

    // MARK: - addTask return value

    @Test func addTaskReturnsCancellableThatIsSafeToCancelAfterReturn() {
        let executor = SerialTaskExecutor()
        let token: AnyCancellable = executor.addTask { }
        // Cancelling an already-returned token must not crash, and a second
        // cancel must be a safe no-op (AnyCancellable cancels at most once).
        token.cancel()
        token.cancel()
    }

    @Test func addTaskResultIsDiscardableWithoutWarning() async {
        let executor = SerialTaskExecutor()
        let ran = Flag()
        // @discardableResult: calling without binding the AnyCancellable must
        // compile (no "result unused" warning) and the task must still run.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                ran.set()
                cont.resume()
            }
        }
        #expect(ran.isSet)
    }

    // MARK: - runTask

    @Test func runTaskWaitsForOperationToFinish() async throws {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let release = Gate()
        let finished = Flag()
        let returned = Flag()
        defer { release.open() }

        let caller = Task {
            let result = try await executor.runTask {
                started.open()
                await release.wait()
                finished.set()
                return "completed"
            }
            returned.set()
            return result
        }

        await started.wait()
        await Self.drainCooperatively()
        #expect(returned.isSet == false)
        #expect(finished.isSet == false)

        release.open()
        let result = try await caller.value
        #expect(result == "completed")
        #expect(finished.isSet)
        #expect(returned.isSet)
    }

    @Test(arguments: [nil, "value"])
    func runTaskPreservesOptionalResult(_ expected: String?) async throws {
        let executor = SerialTaskExecutor()
        let result: String? = try await executor.runTask { expected }
        #expect(result == expected)
    }

    @Test func runTaskPropagatesOperationErrorAndKeepsQueueUsable() async throws {
        let executor = SerialTaskExecutor()

        await #expect(throws: OperationError.failed(42)) {
            _ = try await executor.runTask { () async throws -> String in
                await Task.yield()
                throw OperationError.failed(42)
            }
        }

        let result = try await executor.runTask { "next" }
        #expect(result == "next")
    }

    @Test func runTaskDoesNotWaitForLaterOperations() async throws {
        let executor = SerialTaskExecutor()
        let laterStarted = Gate()
        let release = Gate()
        let laterFinished = Flag()
        defer { release.open() }

        let result = try await executor.runTask {
            executor.addTask {
                laterStarted.open()
                await release.wait()
                laterFinished.set()
            }
            return "current"
        }

        #expect(result == "current")
        await laterStarted.wait()
        #expect(laterFinished.isSet == false)
        release.open()
        try await executor.runTask {}
        #expect(laterFinished.isSet)
    }

    @Test func runTaskSharesFIFOQueueWithAddTask() async throws {
        let executor = SerialTaskExecutor()
        let recorder = Recorder()
        let firstStarted = Gate()
        let release = Gate()
        defer { release.open() }

        executor.addTask {
            recorder.append(1)
            firstStarted.open()
            await release.wait()
            recorder.append(2)
        }
        await firstStarted.wait()

        // Start inline so runTask enqueues before the next addTask call.
        let caller = Task.immediate {
            try await executor.runTask {
                recorder.append(3)
                await Task.yield()
                recorder.append(4)
                return "first"
            }
        }
        executor.addTask { recorder.append(5) }

        release.open()
        let firstResult = try await caller.value
        let lastResult = try await executor.runTask {
            recorder.append(6)
            return 6
        }
        #expect(firstResult == "first")
        #expect(lastResult == 6)
        #expect(recorder.values == [1, 2, 3, 4, 5, 6])
    }

    @Test(arguments: [
        nil,
        TaskPriority.high,
        TaskPriority.medium,
        TaskPriority.low,
        TaskPriority.background,
        TaskPriority.utility,
        TaskPriority.userInitiated
    ])
    func runTaskUsesConfiguredPriority(_ priority: TaskPriority?) async throws {
        let expectedPriority = priority ?? Task.currentPriority
        let executor = SerialTaskExecutor(priority: priority)

        let actualPriority = try await executor.runTask { Task.currentPriority }
        #expect(actualPriority == expectedPriority)
    }

    @Test func runTaskSkipsOperationWhenCallerIsAlreadyCancelled() async throws {
        let executor = SerialTaskExecutor()
        let release = Gate()
        let ran = Flag()

        let caller = Task {
            await release.wait()
            return try await executor.runTask {
                ran.set()
                return "unexpected"
            }
        }
        caller.cancel()
        release.open()
        await #expect(throws: CancellationError.self) {
            _ = try await caller.value
        }
        try await executor.runTask {}

        #expect(ran.isSet == false)
    }

    @Test(arguments: [false, true])
    func cancellingPendingRunTaskResumesCallerWithoutRunningOperation(cancelAll: Bool) async throws {
        let executor = SerialTaskExecutor()
        let firstStarted = Gate()
        let release = Gate()
        let ran = Flag()
        defer { release.open() }

        executor.addTask {
            firstStarted.open()
            await release.wait()
            #expect(Task.isCancelled == cancelAll)
        }
        await firstStarted.wait()

        // Start inline so cancellation happens after runTask has enqueued.
        let caller = Task.immediate {
            try await executor.runTask {
                ran.set()
                return "unexpected"
            }
        }

        if cancelAll {
            executor.cancelAll()
        } else {
            caller.cancel()
        }
        await #expect(throws: CancellationError.self) {
            _ = try await caller.value
        }
        #expect(ran.isSet == false)

        release.open()
        try await executor.runTask {}
        #expect(ran.isSet == false)
    }

    @Test(arguments: [false, true])
    func cancellingRunningRunTaskWaitsForOperationToFinish(cancelAll: Bool) async throws {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let cancelled = Gate()
        let release = Gate()
        let finished = Flag()
        let returned = Flag()
        defer { release.open() }

        let caller = Task {
            let result = try await executor.runTask {
                await withTaskCancellationHandler {
                    started.open()
                    await release.wait()
                    #expect(Task.isCancelled)
                    finished.set()
                    return "completed"
                } onCancel: {
                    cancelled.open()
                }
            }
            returned.set()
            return result
        }

        await started.wait()
        if cancelAll {
            executor.cancelAll()
        } else {
            caller.cancel()
        }
        await cancelled.wait()
        await Self.drainCooperatively()
        #expect(returned.isSet == false)
        #expect(finished.isSet == false)

        release.open()
        let result = try await caller.value
        #expect(result == "completed")
        #expect(finished.isSet)
        #expect(returned.isSet)
    }

    @Test(arguments: [false, true])
    func cancellingRunningThrowingRunTaskPropagatesError(cancelAll: Bool) async {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let release = Gate()
        defer { release.open() }

        let caller = Task {
            try await executor.runTask {
                started.open()
                await release.wait()
                try Task.checkCancellation()
                return "unexpected"
            }
        }

        await started.wait()
        if cancelAll {
            executor.cancelAll()
        } else {
            caller.cancel()
        }
        release.open()
        await #expect(throws: CancellationError.self) {
            _ = try await caller.value
        }
    }

    @Test func runTaskCancellationHandlerCanCancelAll() async throws {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let cancelled = Gate()

        let caller = Task {
            try await executor.runTask {
                await withTaskCancellationHandler {
                    started.open()
                    await cancelled.wait()
                } onCancel: {
                    executor.cancelAll()
                    cancelled.open()
                }
            }
        }

        await started.wait()
        caller.cancel()
        try await caller.value
    }

    @Test func concurrentRunTaskCallsExecuteSeriallyAndExactlyOnce() async throws {
        let executor = SerialTaskExecutor()
        let total = 100
        let recorder = Recorder()
        let detector = OverlapDetector()

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<total {
                group.addTask {
                    try await executor.runTask {
                        detector.enter()
                        await Task.yield()
                        recorder.append(i)
                        detector.leave()
                        return i
                    }
                }
            }
            var results = Set<Int>()
            for try await result in group {
                results.insert(result)
            }
            return results
        }

        #expect(detector.peak == 1)
        #expect(recorder.count == total)
        #expect(Set(recorder.values) == Set(0..<total))
        #expect(results == Set(0..<total))
    }

    @Test func runTaskHandlesRacingCancellationAndCompletion() async throws {
        let executor = SerialTaskExecutor()
        let total = 200
        let counters = (0..<total).map { _ in Counter() }
        let returned = Counter()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                group.addTask {
                    let caller = Task {
                        try await executor.runTask {
                            counters[i].increment()
                            await Task.yield()
                            return i
                        }
                    }
                    await Task.yield()
                    caller.cancel()
                    executor.cancelAll()
                    caller.cancel()
                    switch await caller.result {
                    case let .success(value):
                        #expect(value == i)
                    case let .failure(error):
                        #expect(error is CancellationError)
                    }
                    returned.increment()
                }
            }
        }

        #expect(returned.value == total)
        for counter in counters {
            #expect(counter.value <= 1)
        }
        let result = try await executor.runTask { "still usable" }
        #expect(result == "still usable")
    }

    // MARK: - Happy path: a single task runs

    @Test func singleTaskRuns() async {
        let executor = SerialTaskExecutor()
        await confirmation("single task executes") { confirm in
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                executor.addTask {
                    confirm()
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Boundary: exactly two tasks preserve order

    @Test func twoTasksRunInInsertionOrder() async {
        let executor = SerialTaskExecutor()
        let recorder = Recorder()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { recorder.append(1) }
            executor.addTask {
                recorder.append(2)
                cont.resume()
            }
        }
        #expect(recorder.values == [1, 2])
    }

    // MARK: - Multiple tasks all run

    @Test func allTasksRun() async {
        let executor = SerialTaskExecutor()
        let total = 50
        let recorder = Recorder()

        await confirmation("all tasks execute", expectedCount: total) { confirm in
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                for i in 0..<total {
                    executor.addTask {
                        recorder.append(i)
                        confirm()
                        if i == total - 1 {
                            cont.resume()
                        }
                    }
                }
            }
        }
        #expect(recorder.count == total)
        // All distinct indices ran exactly once.
        #expect(Set(recorder.values) == Set(0..<total))
    }

    // MARK: - Serial FIFO ordering guarantee

    @Test func executesSeriallyInFIFOOrder() async {
        let executor = SerialTaskExecutor()
        let total = 200
        let recorder = Recorder()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            for i in 0..<total {
                executor.addTask {
                    recorder.append(i)
                    if i == total - 1 {
                        cont.resume()
                    }
                }
            }
        }

        // Because the executor runs tasks one-at-a-time off a single worker
        // pulling a FIFO AsyncStream, the recorded order must equal the
        // insertion order exactly.
        #expect(recorder.values == Array(0..<total))
    }

    /// Each task awaits (suspends the worker) mid-flight, yet ordering must still
    /// be exact insertion order. This is a stronger ordering check than the
    /// straight-line version because every task hits a suspension point.
    @Test func fifoOrderHoldsEvenWhenEachTaskSuspends() async {
        let executor = SerialTaskExecutor()
        let total = 150
        let recorder = Recorder()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            for i in 0..<total {
                executor.addTask {
                    await Task.yield()
                    recorder.append(i)
                    await Task.yield()
                    if i == total - 1 {
                        cont.resume()
                    }
                }
            }
        }

        #expect(recorder.values == Array(0..<total))
    }

    /// Even when each task awaits (yields the worker) mid-flight, the next task
    /// must not begin until the current one fully completes — proving serial,
    /// non-overlapping execution.
    @Test func tasksDoNotOverlap() async {
        let executor = SerialTaskExecutor()
        let total = 100
        let detector = OverlapDetector()
        let recorder = Recorder()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            for i in 0..<total {
                executor.addTask {
                    detector.enter()
                    // Yield to give any (incorrectly) overlapping task a chance to run.
                    await Task.yield()
                    detector.leave()

                    recorder.append(i)
                    if i == total - 1 {
                        cont.resume()
                    }
                }
            }
        }

        #expect(detector.peak == 1)
        #expect(recorder.count == total)
    }

    // MARK: - Re-entrancy: a task can enqueue more work onto the same executor

    /// A running operation enqueues a follow-up task on the same executor. The
    /// follow-up must run (after the current one, preserving the serial model)
    /// and the executor must not deadlock.
    @Test func taskCanEnqueueFurtherWorkOntoSameExecutor() async {
        let executor = SerialTaskExecutor()
        let recorder = Recorder()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                recorder.append(0)
                // Re-entrant enqueue from inside a running operation.
                executor.addTask {
                    recorder.append(1)
                    executor.addTask {
                        recorder.append(2)
                        cont.resume()
                    }
                }
            }
        }

        // Each re-entrant task runs after the one that scheduled it.
        #expect(recorder.values == [0, 1, 2])
    }

    // MARK: - Cancellation of a pending (not-yet-started) task

    /// Block the worker with a long task, queue a follow-up, cancel the follow-up
    /// before the worker reaches it. The follow-up's operation must never run.
    @Test func cancellingPendingTaskPreventsExecution() async {
        let executor = SerialTaskExecutor()
        let release = Gate()
        let firstStarted = Gate()
        let secondRan = Flag()

        // First task holds the single worker until we release it.
        executor.addTask {
            firstStarted.open()
            await release.wait()
        }

        // Wait until the first task is actually running so the second is queued
        // strictly behind it.
        await firstStarted.wait()

        // Queue the second task and immediately cancel it. Since the worker is
        // busy with the first task, the second has not been started yet, so its
        // LazyTask.start() should observe isCancelled==true with task==nil and
        // return nil -> operation never invoked.
        let token = executor.addTask {
            secondRan.set()
        }
        token.cancel()

        // Use a third task as a barrier: once it completes we know the worker
        // has drained everything queued up to this point.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                cont.resume()
            }
            // Now allow the first (blocking) task to finish so the worker drains.
            release.open()
        }

        #expect(secondRan.isSet == false)
    }

    // MARK: - cancelAll prevents queued tasks from running

    @Test func cancelAllPreventsQueuedTasks() async {
        let executor = SerialTaskExecutor()
        let release = Gate()
        let firstStarted = Gate()
        let recorder = Recorder()

        executor.addTask {
            firstStarted.open()
            await release.wait()
        }
        await firstStarted.wait()

        // Queue a batch that should be cancelled.
        for i in 0..<20 {
            executor.addTask {
                recorder.append(i)
            }
        }

        executor.cancelAll()

        // Barrier task to know the worker has drained whatever survived.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                cont.resume()
            }
            release.open()
        }

        // None of the cancelled batch should have recorded anything.
        #expect(recorder.count == 0)
    }

    @Test func cancelAllOnEmptyExecutorIsSafeAndStillAllowsLaterTasks() async {
        let executor = SerialTaskExecutor()
        executor.cancelAll()
        executor.cancelAll() // idempotent / no crash

        // The executor must remain usable after cancelAll on an empty queue:
        // a task added afterward should still run.
        let ran = Flag()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                ran.set()
                cont.resume()
            }
        }
        #expect(ran.isSet)
    }

    @Test func cancelAllAfterAllTasksFinishedIsSafe() async {
        let executor = SerialTaskExecutor()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { cont.resume() }
        }
        // Let the worker fully finish the iteration (clearing the tokens map)
        // before cancelAll, exercising cancelAll over an already-drained map.
        await Self.drainCooperatively(iterations: 200)
        executor.cancelAll()

        // Still usable afterward.
        let ran = Flag()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                ran.set()
                cont.resume()
            }
        }
        #expect(ran.isSet)
    }

    // MARK: - Cancellation observed inside a running operation

    /// A running operation that polls Task.isCancelled should observe
    /// cancellation when cancelAll() is invoked, letting it stop early.
    @Test func runningTaskObservesCancellationFromCancelAll() async {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let observedCancellation = Flag()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask {
                started.open()
                // Spin yielding until cancellation is observed.
                for _ in 0..<10_000_000 {
                    if Task.isCancelled {
                        observedCancellation.set()
                        break
                    }
                    await Task.yield()
                }
                cont.resume()
            }

            // Once running, cancel everything; the running op should see it.
            Task {
                await started.wait()
                executor.cancelAll()
            }
        }

        #expect(observedCancellation.isSet == true)
    }

    @Test func cancellingTokenOfRunningTaskIsObserved() async {
        let executor = SerialTaskExecutor()
        let started = Gate()
        let observedCancellation = Flag()

        nonisolated(unsafe) var token: AnyCancellable?

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            token = executor.addTask {
                started.open()
                for _ in 0..<10_000_000 {
                    if Task.isCancelled {
                        observedCancellation.set()
                        break
                    }
                    await Task.yield()
                }
                cont.resume()
            }

            Task {
                await started.wait()
                token?.cancel()
            }
        }

        #expect(observedCancellation.isSet == true)
    }

    // MARK: - Concurrency stress: many concurrent producers

    /// Add tasks concurrently from many child tasks; the executor must run all
    /// of them exactly once with no lost updates and no crash.
    @Test func concurrentAddTaskRunsEveryTaskExactlyOnce() async {
        let executor = SerialTaskExecutor()
        let total = 500
        let recorder = Recorder()

        await confirmation("every concurrently-added task runs once", expectedCount: total) { confirm in
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<total {
                    group.addTask {
                        executor.addTask {
                            recorder.append(i)
                            confirm()
                        }
                    }
                }
                await group.waitForAll()
            }

            // Drain barrier: enqueue a final task and await it so all prior
            // tasks have completed before the confirmation scope ends.
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                executor.addTask { cont.resume() }
            }
        }

        #expect(recorder.count == total)
        // No duplicates / no missing values: the set must be exactly 0..<total.
        #expect(Set(recorder.values) == Set(0..<total))
    }

    /// Each added task is run exactly once (never twice) even when the same
    /// token is cancelled concurrently after the worker may already have started
    /// it. The executor must never invoke an operation more than once.
    @Test func eachTaskRunsAtMostOnceUnderConcurrentCancellation() async {
        let executor = SerialTaskExecutor()
        let total = 300
        let counters = (0..<total).map { _ in Counter() }
        let ranAtLeastOnce = Counter()

        await withTaskGroup(of: Void.self) { group in
            // Producers add tasks.
            for i in 0..<total {
                group.addTask {
                    let token = executor.addTask {
                        if counters[i].value == 0 { ranAtLeastOnce.increment() }
                        counters[i].increment()
                    }
                    // Racing cancellation: some will be cancelled before start,
                    // some after start, some after completion.
                    if i % 3 == 0 {
                        token.cancel()
                    }
                }
            }
            await group.waitForAll()
        }

        // Barrier to drain anything still queued.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { cont.resume() }
        }

        // Core safety invariant: no operation ever ran more than once.
        for c in counters {
            #expect(c.value <= 1)
        }
        // And it is not vacuously true: at least the tasks that were never
        // cancelled must have run.
        #expect(ranAtLeastOnce.value >= 1)
    }

    // MARK: - Large data / time-bounded throughput

    @Test func largeNumberOfTinyTasksAllComplete() async {
        let executor = SerialTaskExecutor()
        let total = 5_000
        let accumulator = Accumulator()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            for i in 0..<total {
                executor.addTask {
                    accumulator.add(i)
                    if i == total - 1 {
                        cont.resume()
                    }
                }
            }
        }

        let expected = (0..<total).reduce(0, +)
        #expect(accumulator.sum == expected)
    }

    // MARK: - Independence of separate executors

    @Test func separateExecutorsAreIndependent() async {
        let a = SerialTaskExecutor()
        let b = SerialTaskExecutor()
        let ra = Recorder()
        let rb = Recorder()

        await confirmation(expectedCount: 2) { confirm in
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let done = Recorder()
                a.addTask {
                    ra.append(1)
                    confirm()
                    done.append(1)
                    if done.count == 2 { cont.resume() }
                }
                b.addTask {
                    rb.append(2)
                    confirm()
                    done.append(2)
                    if done.count == 2 { cont.resume() }
                }
            }
        }

        #expect(ra.values == [1])
        #expect(rb.values == [2])
    }

    /// Cancelling all work on one executor must not affect a sibling executor.
    @Test func cancelAllOnOneExecutorDoesNotAffectAnother() async {
        let a = SerialTaskExecutor()
        let b = SerialTaskExecutor()
        let release = Gate()
        let aBlocked = Gate()
        let aRecorder = Recorder()
        let bRan = Flag()

        // Block executor a so we can queue + cancel work on it.
        a.addTask {
            aBlocked.open()
            await release.wait()
        }
        await aBlocked.wait()
        a.addTask { aRecorder.append(99) }
        a.cancelAll()
        release.open()

        // Executor b is wholly unaffected and runs its task.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            b.addTask {
                bRan.set()
                cont.resume()
            }
        }

        await Self.drainCooperatively()
        #expect(bRan.isSet)
        #expect(aRecorder.count == 0)
    }

    // MARK: - deinit drops queued work without crashing

    /// When the executor is deallocated, its deinit calls cancelAll(),
    /// finishes the stream and cancels the worker. Tasks queued behind a blocked
    /// worker should be dropped without crashing. We verify no crash and that
    /// the executor can be released while work is outstanding.
    @Test func deinitWhileBusyDoesNotCrash() async {
        let release = Gate()
        let firstStarted = Gate()
        let ranAfter = Flag()

        do {
            let executor = SerialTaskExecutor()
            executor.addTask {
                firstStarted.open()
                await release.wait()
            }
            await firstStarted.wait()
            executor.addTask {
                ranAfter.set()
            }
            // executor goes out of scope here -> deinit runs cancelAll() etc.
        }

        // Release the gate so the (now-cancelled / detached) first task can exit.
        release.open()

        // Give cooperative scheduling a chance via an explicit yield-based barrier
        // rather than sleeping. Spin a bounded number of yields.
        await Self.drainCooperatively()

        // The second task, queued behind the blocked first task, should not have
        // executed because deinit cancelled all pending work.
        #expect(ranAfter.isSet == false)
    }

    /// Deinitializing an idle (drained) executor must be safe and not crash.
    @Test func deinitWhileIdleDoesNotCrash() async {
        do {
            let executor = SerialTaskExecutor()
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                executor.addTask { cont.resume() }
            }
            // Executor released here while idle.
        }
        await Self.drainCooperatively(iterations: 200)
        // Reaching here without a crash is the assertion.
        #expect(Bool(true))
    }

    // MARK: - addTask with a no-op closure still drains cleanly

    @Test func emptyOperationsDrain() async {
        let executor = SerialTaskExecutor()
        let recorder = Recorder()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            for _ in 0..<10 { executor.addTask { } }
            executor.addTask {
                recorder.append(1)
                cont.resume()
            }
        }
        // The trailing barrier task ran after the 10 no-op tasks drained.
        #expect(recorder.values == [1])
    }

    // MARK: - Cancelling one token does not affect others

    @Test func cancellingOneTokenDoesNotCancelOthers() async {
        let executor = SerialTaskExecutor()
        let release = Gate()
        let firstStarted = Gate()
        let recorder = Recorder()

        executor.addTask {
            firstStarted.open()
            await release.wait()
        }
        await firstStarted.wait()

        // Queue three tasks; cancel only the middle one.
        executor.addTask { recorder.append(0) }
        let cancelMe = executor.addTask { recorder.append(1) }
        executor.addTask { recorder.append(2) }
        cancelMe.cancel()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { cont.resume() }
            release.open()
        }

        // Task 0 and Task 2 must run; Task 1 must not.
        #expect(recorder.values.contains(0))
        #expect(recorder.values.contains(2))
        #expect(recorder.values.contains(1) == false)
        // FIFO preserved among survivors.
        #expect(recorder.values == [0, 2])
    }

    /// Cancelling the *first* queued (still-pending) task while the worker is
    /// blocked must skip only that one; the rest run in FIFO order.
    @Test func cancellingFirstPendingTaskSkipsOnlyIt() async {
        let executor = SerialTaskExecutor()
        let release = Gate()
        let firstStarted = Gate()
        let recorder = Recorder()

        executor.addTask {
            firstStarted.open()
            await release.wait()
        }
        await firstStarted.wait()

        let cancelFirst = executor.addTask { recorder.append(0) }
        executor.addTask { recorder.append(1) }
        executor.addTask { recorder.append(2) }
        cancelFirst.cancel()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { cont.resume() }
            release.open()
        }

        #expect(recorder.values == [1, 2])
    }
}
