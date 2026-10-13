//
//  TaskQueueTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/TaskQueue.swift
//
//  Public surface under test:
//    - TaskQueue.init(maxConcurrentTasks:priority:)
//    - TaskQueue.addTask(isBarrier:_:) -> AnyCancellable   (@discardableResult)
//    - TaskQueue.runTask<Success: Sendable>(isBarrier:_:) async throws -> Success
//    - TaskQueue.cancelAll()
//    - deinit behavior (indirect)
//
//  LazyTask is `private`, so it is exercised only indirectly through the
//  executor's public surface.
//

import Combine
import Dispatch
import Foundation
import Testing
@testable import SwiftCodeBook

#if os(macOS)
import Darwin
#endif

@Suite(.timeLimit(.minutes(1))) struct TaskQueueTests {

    // MARK: - Test helpers (private, nested to avoid module-wide name collisions)

    private enum OperationError: Error, Equatable {
        case failed(Int)
    }

    private final class ReleaseObserver: Sendable {
        private let onDeinit: @Sendable () -> Void

        init(_ onDeinit: @Sendable @escaping () -> Void) {
            self.onDeinit = onDeinit
        }

        deinit {
            onDeinit()
        }
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
    /// peak, which must never exceed the configured concurrency limit.
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
        let executor = TaskQueue()
        let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
            executor.addTask {
                cont.resume(returning: Task.currentPriority)
            }
        }
        #expect(actualPriority == expectedPriority)
    }

    @Test(arguments: [0, 1, 3], [
        TaskPriority.high,
        TaskPriority.medium,
        TaskPriority.low,
        TaskPriority.background,
        TaskPriority.utility,
        TaskPriority.userInitiated
    ])
    func runsTasksAtExplicitPriority(_ maxConcurrentTasks: Int, _ priority: TaskPriority) async {
        let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks, priority: priority)
        for isBarrier in [false, true] {
            let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
                executor.addTask(isBarrier: isBarrier) {
                    cont.resume(returning: Task.currentPriority)
                }
            }
            #expect(actualPriority == priority)
        }
    }

    @Test func inheritsPriorityWhenInitializedWithNilPriority() async {
        let expectedPriority = Task.currentPriority
        let executor = TaskQueue(priority: nil)
        let actualPriority = await withCheckedContinuation { (cont: CheckedContinuation<TaskPriority, Never>) in
            executor.addTask {
                cont.resume(returning: Task.currentPriority)
            }
        }
        #expect(actualPriority == expectedPriority)
    }

    // MARK: - Configurable concurrency

    @Test(arguments: [1, 2, 4, 64, 0, -1, Int.min])
    func mixedSubmissionsRespectConcurrencyLimit(_ maxConcurrentTasks: Int) async throws {
        let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let total = 24
        let expectedConcurrency = maxConcurrentTasks > 0 ? min(maxConcurrentTasks, total) : total
        let saturated = Gate()
        let release = Gate()
        let completed = (0..<total).map { _ in Gate() }
        let recorder = Recorder()
        let detector = OverlapDetector()
        defer { release.open() }

        try await withThrowingTaskGroup(of: Int.self) { group in
            for id in 0..<total {
                let operation: @Sendable () async -> Int = {
                    detector.enter()
                    recorder.append(id)
                    if recorder.count >= expectedConcurrency { saturated.open() }
                    await release.wait()
                    await Task.yield()
                    detector.leave()
                    completed[id].open()
                    return id
                }
                if id.isMultiple(of: 2) {
                    executor.addTask { _ = await operation() }
                } else {
                    group.addTask { try await executor.runTask(operation) }
                }
            }

            await saturated.wait()
            await Self.drainCooperatively()
            #expect(recorder.count == expectedConcurrency)
            #expect(detector.peak == expectedConcurrency)

            release.open()
            for gate in completed { await gate.wait() }
            var results = Set<Int>()
            for try await result in group {
                #expect(results.insert(result).inserted)
            }
            #expect(results == Set(stride(from: 1, to: total, by: 2)))
        }

        #expect(recorder.count == total)
        #expect(Set(recorder.values) == Set(0..<total))
        #expect(detector.peak == expectedConcurrency)
    }

    @Test func refillsSlotWhenLaterConcurrentOperationThrows() async throws {
        let executor = TaskQueue(maxConcurrentTasks: 2)
        let firstStarted = Gate()
        let firstFinished = Gate()
        let releaseFirst = Gate()
        let secondStarted = Gate()
        let releaseSecond = Gate()
        defer {
            releaseFirst.open()
            releaseSecond.open()
        }

        executor.addTask {
            firstStarted.open()
            await releaseFirst.wait()
            firstFinished.open()
        }
        await firstStarted.wait()
        let failing = Task.immediate {
            try await executor.runTask { () async throws -> Int in
                secondStarted.open()
                await releaseSecond.wait()
                throw OperationError.failed(2)
            }
        }
        await secondStarted.wait()
        let replacement = Task.immediate {
            try await executor.runTask { "replacement" }
        }

        releaseSecond.open()
        await #expect(throws: OperationError.failed(2)) { try await failing.value }
        let result = try await replacement.value
        #expect(result == "replacement")

        releaseFirst.open()
        await firstFinished.wait()
    }

    @Test(arguments: [false, true])
    func cancelledConcurrentOperationsKeepSlotsUntilTheyFinish(cancelAll: Bool) async throws {
        let executor = TaskQueue(maxConcurrentTasks: 2)
        let started = (0..<2).map { _ in Gate() }
        let cancelled = (0..<2).map { _ in Gate() }
        let release = (0..<2).map { _ in Gate() }
        let finished = (0..<2).map { _ in Gate() }
        let skippedRuns = Counter()
        defer { for gate in release { gate.open() } }

        let tokens = (0..<2).map { id in
            executor.addTask {
                await withTaskCancellationHandler {
                    started[id].open()
                    await release[id].wait()
                    #expect(Task.isCancelled)
                } onCancel: {
                    cancelled[id].open()
                }
                finished[id].open()
            }
        }
        for gate in started { await gate.wait() }
        let pendingToken = executor.addTask { skippedRuns.increment() }
        let pendingCaller = Task.immediate {
            try await executor.runTask {
                skippedRuns.increment()
                return "unexpected"
            }
        }

        if cancelAll {
            executor.cancelAll()
        } else {
            for token in tokens { token.cancel() }
            pendingToken.cancel()
            pendingCaller.cancel()
        }
        for gate in cancelled { await gate.wait() }
        await #expect(throws: CancellationError.self) { try await pendingCaller.value }

        let replacementStarted = Flag()
        let replacement = Task.immediate {
            try await executor.runTask {
                #expect(Task.isCancelled == false)
                replacementStarted.set()
                return "replacement"
            }
        }
        await Self.drainCooperatively()
        #expect(replacementStarted.isSet == false)
        #expect(skippedRuns.value == 0)

        release[1].open()
        let result = try await replacement.value
        #expect(result == "replacement")
        #expect(skippedRuns.value == 0)

        release[0].open()
        for gate in finished { await gate.wait() }
    }

    @Test func cancelAllInUnlimitedModeAllowsNewWorkBeforeCancelledOperationsFinish() async throws {
        let queue = TaskQueue(maxConcurrentTasks: 0)
        let started = (0..<8).map { _ in Gate() }
        let cancelled = (0..<8).map { _ in Gate() }
        let finished = (0..<8).map { _ in Gate() }
        let release = Gate()
        defer { release.open() }

        for id in 0..<8 {
            queue.addTask {
                await withTaskCancellationHandler {
                    started[id].open()
                    await release.wait()
                    #expect(Task.isCancelled)
                } onCancel: {
                    cancelled[id].open()
                }
                finished[id].open()
            }
        }
        for gate in started { await gate.wait() }
        queue.cancelAll()
        for gate in cancelled { await gate.wait() }

        let result = try await queue.runTask {
            #expect(Task.isCancelled == false)
            return "replacement"
        }
        #expect(result == "replacement")

        release.open()
        for gate in finished { await gate.wait() }
    }

    // MARK: - Barriers

    @Test(arguments: [0, 1, 3], [false, true])
    func barrierWaitsForEarlierTasksAndBlocksLaterTasks(_ maxConcurrentTasks: Int, useRunTask: Bool) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let batchSize = 6
        let expectedConcurrency = maxConcurrentTasks > 0 ? min(maxConcurrentTasks, batchSize) : batchSize
        let earlierStarted = Counter()
        let earlierReady = Gate()
        let earlierFinished = Counter()
        let releaseEarlier = Gate()
        let barrierRuns = Counter()
        let barrierStarted = Gate()
        let barrierFinished = Flag()
        let releaseBarrier = Gate()
        let laterStarted = Counter()
        let laterReady = Gate()
        let laterFinished = (0..<batchSize).map { _ in Gate() }
        let releaseLater = Gate()
        defer {
            releaseEarlier.open()
            releaseBarrier.open()
            releaseLater.open()
        }

        for _ in 0..<batchSize {
            queue.addTask {
                earlierStarted.increment()
                if earlierStarted.value >= expectedConcurrency { earlierReady.open() }
                await releaseEarlier.wait()
                earlierFinished.increment()
            }
        }
        await earlierReady.wait()
        let operation: @Sendable () async -> String = {
            #expect(earlierFinished.value == batchSize)
            barrierRuns.increment()
            barrierStarted.open()
            await releaseBarrier.wait()
            barrierFinished.set()
            return "barrier"
        }
        let caller: Task<String, Error>?
        if useRunTask {
            caller = Task.immediate { try await queue.runTask(isBarrier: true, operation) }
        } else {
            caller = nil
            queue.addTask(isBarrier: true) { _ = await operation() }
        }
        for id in 0..<batchSize {
            queue.addTask {
                #expect(barrierFinished.isSet)
                laterStarted.increment()
                if laterStarted.value >= expectedConcurrency { laterReady.open() }
                await releaseLater.wait()
                laterFinished[id].open()
            }
        }

        await Self.drainCooperatively()
        #expect(barrierRuns.value == 0)
        #expect(laterStarted.value == 0)
        releaseEarlier.open()
        await barrierStarted.wait()
        await Self.drainCooperatively()
        #expect(earlierFinished.value == batchSize)
        #expect(laterStarted.value == 0)

        releaseBarrier.open()
        if let caller {
            let result = try await caller.value
            #expect(result == "barrier")
        }
        await laterReady.wait()
        #expect(laterStarted.value == expectedConcurrency)
        releaseLater.open()
        for gate in laterFinished { await gate.wait() }
        #expect(laterStarted.value == batchSize)
        #expect(barrierRuns.value == 1)
    }

    @Test(arguments: [0, 1, 3])
    func emptyAndConsecutiveBarriersPreserveOrdering(_ maxConcurrentTasks: Int) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let recorder = Recorder()
        queue.addTask(isBarrier: true) { recorder.append(0) }
        let first = Task.immediate {
            try await queue.runTask(isBarrier: true) {
                recorder.append(1)
                await Task.yield()
                recorder.append(2)
                return "first"
            }
        }
        queue.addTask(isBarrier: true) {
            recorder.append(3)
            await Task.yield()
            recorder.append(4)
        }
        let result = try await queue.runTask(isBarrier: true) {
            recorder.append(5)
            return 5
        }

        let firstResult = try await first.value
        #expect(firstResult == "first")
        #expect(result == 5)
        #expect(recorder.values == Array(0...5))
    }

    @Test(arguments: [0, 1, 3])
    func throwingBarrierPropagatesErrorAndReleasesLaterWork(_ maxConcurrentTasks: Int) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let started = Gate()
        let release = Gate()
        let laterStarted = Flag()
        defer { release.open() }
        let barrier = Task.immediate {
            try await queue.runTask(isBarrier: true) { () async throws -> Int in
                started.open()
                await release.wait()
                throw OperationError.failed(42)
            }
        }
        await started.wait()
        let later = Task.immediate {
            try await queue.runTask {
                laterStarted.set()
                return "later"
            }
        }

        await Self.drainCooperatively()
        #expect(laterStarted.isSet == false)
        release.open()
        await #expect(throws: OperationError.failed(42)) { try await barrier.value }
        let result = try await later.value
        #expect(result == "later")
    }

    @Test(arguments: [0, 1, 3], [false, true])
    func cancellingRunningBarrierDoesNotReleaseLaterWorkEarly(_ maxConcurrentTasks: Int, cancelAll: Bool) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let started = Gate()
        let cancelled = Gate()
        let release = Gate()
        let barrierFinished = Flag()
        let laterStarted = Flag()
        defer { release.open() }
        let barrier = Task.immediate {
            try await queue.runTask(isBarrier: true) {
                await withTaskCancellationHandler {
                    started.open()
                    await release.wait()
                    #expect(Task.isCancelled)
                    barrierFinished.set()
                    return "barrier"
                } onCancel: {
                    cancelled.open()
                }
            }
        }
        await started.wait()
        if cancelAll {
            queue.cancelAll()
        } else {
            barrier.cancel()
        }
        await cancelled.wait()
        let later = Task.immediate {
            try await queue.runTask {
                #expect(barrierFinished.isSet)
                #expect(Task.isCancelled == false)
                laterStarted.set()
                return "later"
            }
        }

        await Self.drainCooperatively()
        #expect(laterStarted.isSet == false)
        release.open()
        let barrierResult = try await barrier.value
        let laterResult = try await later.value
        #expect(barrierResult == "barrier")
        #expect(laterResult == "later")
    }

    @Test(arguments: [0, 1, 3], [false, true])
    func cancellingPendingBarriersSkipsBodiesButPreservesOrdering(_ maxConcurrentTasks: Int, cancelAll: Bool) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let started = Gate()
        let release = Gate()
        let earlierFinished = Flag()
        let barrierRuns = Counter()
        let laterStarted = Flag()
        defer { release.open() }
        queue.addTask {
            started.open()
            await release.wait()
            #expect(Task.isCancelled == cancelAll)
            earlierFinished.set()
        }
        await started.wait()
        let token = queue.addTask(isBarrier: true) { barrierRuns.increment() }
        let caller = Task.immediate {
            try await queue.runTask(isBarrier: true) { barrierRuns.increment() }
        }
        if cancelAll {
            queue.cancelAll()
        } else {
            token.cancel()
            caller.cancel()
        }
        await #expect(throws: CancellationError.self) { try await caller.value }
        let later = Task.immediate {
            try await queue.runTask {
                #expect(earlierFinished.isSet)
                #expect(Task.isCancelled == false)
                laterStarted.set()
                return "later"
            }
        }

        await Self.drainCooperatively()
        #expect(laterStarted.isSet == false)
        release.open()
        let result = try await later.value
        #expect(result == "later")
        #expect(barrierRuns.value == 0)
    }

    @Test(arguments: [0, 1, 3])
    func barrierCanEnqueueLaterWorkWithoutRunningItEarly(_ maxConcurrentTasks: Int) async throws {
        let queue = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let started = Gate()
        let release = Gate()
        let childStarted = Flag()
        let childFinished = Gate()
        defer { release.open() }
        let barrier = Task.immediate {
            try await queue.runTask(isBarrier: true) {
                queue.addTask {
                    childStarted.set()
                    childFinished.open()
                }
                started.open()
                await release.wait()
                #expect(childStarted.isSet == false)
            }
        }
        await started.wait()
        await Self.drainCooperatively()
        #expect(childStarted.isSet == false)
        release.open()
        try await barrier.value
        await childFinished.wait()
    }

    #if os(macOS)
    @Test func reentrantRunTaskFromBarrierFailsFast() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                Darwin._exit(EXIT_SUCCESS)
            }
            let queue = TaskQueue(maxConcurrentTasks: 0)
            await withCheckedContinuation { (completed: CheckedContinuation<Void, Never>) in
                queue.addTask(isBarrier: true) {
                    do {
                        try await queue.runTask {}
                    } catch {
                        Issue.record(error)
                        Darwin._exit(EXIT_SUCCESS)
                    }
                    completed.resume()
                }
            }
        }
        #expect(result != nil)
        #if DEBUG
        if let result {
            let message = String(decoding: result.standardErrorContent, as: UTF8.self)
            #expect(message.contains("TaskQueue.runTask cannot be awaited from an operation running on the same queue."))
        }
        #endif
    }
    #endif

    // MARK: - addTask return value

    @Test func addTaskReturnsCancellableThatIsSafeToCancelAfterReturn() {
        let executor = TaskQueue()
        let token: AnyCancellable = executor.addTask { }
        // Cancelling an already-returned token must not crash, and a second
        // cancel must be a safe no-op (AnyCancellable cancels at most once).
        token.cancel()
        token.cancel()
    }

    @Test func addTaskResultIsDiscardableWithoutWarning() async {
        let executor = TaskQueue()
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

    @Test func taskRetainsDiscardedCancellableUntilCompletion() async throws {
        let executor = TaskQueue()
        let firstStarted = Gate()
        let releaseFirst = Gate()
        let secondStarted = Gate()
        let releaseSecond = Gate()
        defer {
            releaseFirst.open()
            releaseSecond.open()
        }

        executor.addTask {
            firstStarted.open()
            await releaseFirst.wait()
        }
        await firstStarted.wait()

        weak var retainedToken: AnyCancellable?
        do {
            let token = executor.addTask {
                #expect(Task.isCancelled == false)
                secondStarted.open()
                await releaseSecond.wait()
                #expect(Task.isCancelled == false)
            }
            retainedToken = token
        }

        #expect(retainedToken != nil)
        releaseFirst.open()
        await secondStarted.wait()
        #expect(retainedToken != nil)

        releaseSecond.open()
        try await executor.runTask {}
        #expect(retainedToken == nil)
    }

    @Test func retainedCancellableDoesNotRetainCompletedOperation() async throws {
        let executor = TaskQueue()
        weak var capturedFlag: Flag?
        let token: AnyCancellable
        do {
            let flag = Flag()
            capturedFlag = flag
            token = executor.addTask { flag.set() }
        }

        try await executor.runTask {}
        withExtendedLifetime(token) {
            #expect(capturedFlag == nil)
            token.cancel()
        }
    }

    @Test(arguments: [false, true])
    func cancellingPendingTaskReleasesOperationCaptures(cancelAll: Bool) async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        let ran = Flag()
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        weak var capturedFlag: Flag?
        let token: AnyCancellable
        do {
            let flag = Flag()
            capturedFlag = flag
            token = executor.addTask {
                flag.set()
                ran.set()
            }
        }

        if cancelAll {
            executor.cancelAll()
        } else {
            token.cancel()
        }
        #expect(capturedFlag == nil)
        #expect(ran.isSet == false)

        release.open()
        try await executor.runTask {}
        #expect(ran.isSet == false)
    }

    @Test(arguments: [false, true])
    func cancellingPendingRunTaskReleasesOperationCaptures(cancelAll: Bool) async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        weak var capturedFlag: Flag?
        let caller: Task<String, Error>
        do {
            let flag = Flag()
            capturedFlag = flag
            caller = Task.immediate {
                try await executor.runTask {
                    flag.set()
                    return "unexpected"
                }
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
        #expect(capturedFlag == nil)

        release.open()
        try await executor.runTask {}
    }

    @Test func finishedOperationReleasesCapturesOutsideLocks() async throws {
        let executor = TaskQueue()
        let released = Gate()
        do {
            let observer = ReleaseObserver {
                executor.cancelAll()
                executor.addTask { released.open() }
            }
            executor.addTask { withExtendedLifetime(observer) {} }
        }
        executor.addTask {}

        await released.wait()
        try await executor.runTask {}
    }

    // MARK: - runTask

    #if os(macOS)
    @Test func reentrantRunTaskFromAddTaskFailsFast() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            // A deadlock must fail this test instead of hanging the test host.
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                Darwin._exit(EXIT_SUCCESS)
            }
            let executor = TaskQueue()
            await withCheckedContinuation { (completed: CheckedContinuation<Void, Never>) in
                executor.addTask {
                    do {
                        _ = try await executor.runTask { "unexpected" }
                    } catch {
                        Issue.record(error)
                        Darwin._exit(EXIT_SUCCESS)
                    }
                    completed.resume()
                }
            }
        }
        #expect(result != nil)
        #if DEBUG
        if let result {
            let message = String(decoding: result.standardErrorContent, as: UTF8.self)
            #expect(message.contains("TaskQueue.runTask cannot be awaited from an operation running on the same queue."))
        }
        #endif
    }

    @Test func reentrantRunTaskFromRunTaskFailsFastAfterActorHop() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                Darwin._exit(EXIT_SUCCESS)
            }
            let executor = TaskQueue()
            let reenter: @MainActor @Sendable () async throws -> String = {
                try await executor.runTask { "unexpected" }
            }
            do {
                _ = try await executor.runTask {
                    await Task.yield()
                    return try await reenter()
                }
            } catch {
                Issue.record(error)
                Darwin._exit(EXIT_SUCCESS)
            }
        }
        #expect(result != nil)
        #if DEBUG
        if let result {
            let message = String(decoding: result.standardErrorContent, as: UTF8.self)
            #expect(message.contains("TaskQueue.runTask cannot be awaited from an operation running on the same queue."))
        }
        #endif
    }

    @Test func reentrantRunTaskFailsFastAfterAnotherConcurrentOperationFinishes() async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                Darwin._exit(EXIT_SUCCESS)
            }
            let executor = TaskQueue(maxConcurrentTasks: 2)
            let firstStarted = Gate()
            let otherFinished = Gate()
            let caller = Task {
                try await executor.runTask {
                    firstStarted.open()
                    await otherFinished.wait()
                    return try await executor.runTask { "unexpected" }
                }
            }
            await firstStarted.wait()
            do {
                _ = try await executor.runTask { "other" }
                otherFinished.open()
                _ = try await caller.value
            } catch {
                Issue.record(error)
                Darwin._exit(EXIT_SUCCESS)
            }
        }
        #expect(result != nil)
        #if DEBUG
        if let result {
            let message = String(decoding: result.standardErrorContent, as: UTF8.self)
            #expect(message.contains("TaskQueue.runTask cannot be awaited from an operation running on the same queue."))
        }
        #endif
    }
    #endif

    @Test func runTaskCanAwaitAnotherExecutor() async throws {
        let first = TaskQueue()
        let second = TaskQueue()
        let result = try await first.runTask {
            await Task.yield()
            return try await second.runTask { "completed" }
        }
        #expect(result == "completed")
    }

    @Test(arguments: [0, 1, 3])
    func independentTaskCanQueueRunTaskFromRunningOperation(_ maxConcurrentTasks: Int) async throws {
        let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let caller = try await executor.runTask {
            Task.immediate {
                try await executor.runTask { "completed" }
            }
        }
        let result = try await caller.value
        #expect(result == "completed")
    }

    @Test func runTaskWaitsForOperationToFinish() async throws {
        let executor = TaskQueue()
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
        let executor = TaskQueue()
        let result: String? = try await executor.runTask { expected }
        #expect(result == expected)
    }

    @Test func runTaskPropagatesOperationErrorAndKeepsQueueUsable() async throws {
        let executor = TaskQueue()

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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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

    @Test(arguments: [0, 1, 3], [
        nil,
        TaskPriority.high,
        TaskPriority.medium,
        TaskPriority.low,
        TaskPriority.background,
        TaskPriority.utility,
        TaskPriority.userInitiated
    ])
    func runTaskUsesConfiguredPriority(_ maxConcurrentTasks: Int, _ priority: TaskPriority?) async throws {
        let expectedPriority = priority ?? Task.currentPriority
        let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks, priority: priority)

        for isBarrier in [false, true] {
            let actualPriority = try await executor.runTask(isBarrier: isBarrier) { Task.currentPriority }
            #expect(actualPriority == expectedPriority)
        }
    }

    @Test func runTaskSkipsOperationWhenCallerIsAlreadyCancelled() async throws {
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        // LazyTask.start() should observe operation==nil with task==nil and
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
        let executor = TaskQueue()
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

    @Test func cancellingOneOfIdenticalOperationsDoesNotAffectOthers() async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        let runs = Counter()
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        let operation: @Sendable () async -> Void = { runs.increment() }
        executor.addTask(operation)
        let cancelled = executor.addTask(operation)
        executor.addTask(operation)
        cancelled.cancel()

        release.open()
        try await executor.runTask {}
        #expect(runs.value == 2)
    }

    @Test func newTasksPreserveFIFOAfterCancellingLargeBacklog() async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        let cancelledRuns = Counter()
        let recorder = Recorder()
        let total = 2_000
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        for _ in 0..<total {
            executor.addTask { cancelledRuns.increment() }
        }
        executor.cancelAll()
        for i in 0..<total {
            executor.addTask { recorder.append(i) }
        }

        release.open()
        let result = try await executor.runTask { "completed" }
        #expect(result == "completed")
        #expect(cancelledRuns.value == 0)
        #expect(recorder.values == Array(0..<total))
    }

    @Test func cancelAllPreventsStartsWhileReleasingCancelledCaptures() async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        let capturedObjectReleased = Flag()
        let cancellationReturned = Flag()
        let newTaskReached = Flag()
        let pendingTaskRan = Flag()
        let barrier = DispatchSemaphore(value: 0)
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        do {
            let observer = ReleaseObserver {
                capturedObjectReleased.set()
                guard !cancellationReturned.isSet else { return }
                release.open()
                executor.addTask { barrier.signal() }
                // Keep cancelAll in progress while the worker drains the old batch.
                if barrier.wait(timeout: .now() + 5) == .success {
                    newTaskReached.set()
                }
            }
            executor.addTask { withExtendedLifetime(observer) {} }
        }
        executor.addTask { pendingTaskRan.set() }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                executor.cancelAll()
                cancellationReturned.set()
                continuation.resume()
            }
        }
        #expect(capturedObjectReleased.isSet)
        #expect(newTaskReached.isSet)
        #expect(pendingTaskRan.isSet == false)

        release.open()
        try await executor.runTask {}
        #expect(pendingTaskRan.isSet == false)
    }

    @Test func cancelAllPreventsQueuedWorkWhenRunningTaskFinishesOnCancellation() async throws {
        let unexpectedRuns = Counter()
        for _ in 0..<2_000 {
            let executor = TaskQueue(priority: .high)
            let started = Gate()
            executor.addTask {
                started.open()
                while !Task.isCancelled { await Task.yield() }
            }
            await started.wait()
            for _ in 0..<16 {
                executor.addTask { unexpectedRuns.increment() }
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .background).async {
                    executor.cancelAll()
                    continuation.resume()
                }
            }
            try await executor.runTask {}
        }
        #expect(unexpectedRuns.value == 0)
    }

    @Test func cancelAllOnEmptyExecutorIsSafeAndStillAllowsLaterTasks() async {
        let executor = TaskQueue()
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
        let executor = TaskQueue()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            executor.addTask { cont.resume() }
        }
        // Let the worker remove completed tasks before cancelling the empty queue.
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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

    @Test func multithreadedProducersPreserveOrderWithoutOverlappingOperations() async throws {
        let executor = TaskQueue()
        let producerCount = 8
        let tasksPerProducer = 250
        let recorder = Recorder()
        let detector = OverlapDetector()

        await withCheckedContinuation { (completed: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.concurrentPerform(iterations: producerCount) { producer in
                    for index in 0..<tasksPerProducer {
                        executor.addTask {
                            detector.enter()
                            defer { detector.leave() }
                            await Task.yield()
                            recorder.append(producer * tasksPerProducer + index)
                        }
                    }
                }
                completed.resume()
            }
        }
        try await executor.runTask {}

        let values = recorder.values
        #expect(values.count == producerCount * tasksPerProducer)
        #expect(Set(values) == Set(0..<(producerCount * tasksPerProducer)))
        #expect(detector.peak == 1)
        for producer in 0..<producerCount {
            let indices = values
                .filter { $0 / tasksPerProducer == producer }
                .map { $0 % tasksPerProducer }
            #expect(indices == Array(0..<tasksPerProducer))
        }
    }

    @Test func multithreadedCancellationDoesNotAffectLaterSubmissions() async throws {
        let executor = TaskQueue()
        let started = Gate()
        let release = Gate()
        let cancelledRuns = Counter()
        let recorder = Recorder()
        defer { release.open() }

        executor.addTask {
            started.open()
            await release.wait()
        }
        await started.wait()

        await withCheckedContinuation { (completed: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.concurrentPerform(iterations: 8) { producer in
                    for index in 0..<250 {
                        let token = executor.addTask { cancelledRuns.increment() }
                        if index.isMultiple(of: 2) { token.cancel() }
                        if (producer + index).isMultiple(of: 5) { executor.cancelAll() }
                    }
                }
                completed.resume()
            }
        }
        executor.cancelAll()

        for index in 0..<250 {
            executor.addTask {
                #expect(Task.isCancelled == false)
                recorder.append(index)
            }
        }
        release.open()
        let result = try await executor.runTask { "completed" }

        #expect(result == "completed")
        #expect(cancelledRuns.value == 0)
        #expect(recorder.values == Array(0..<250))
    }

    @Test(arguments: [0, 1, 4])
    func multithreadedRunTaskCallsCompleteWithTheirOwnResults(_ maxConcurrentTasks: Int) async throws {
        let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
        let producerCount = 8
        let tasksPerProducer = 64
        let total = producerCount * tasksPerProducer
        let counters = (0..<total).map { _ in Counter() }
        let detector = OverlapDetector()
        let (outcomes, continuation) = AsyncStream<(Int, Result<Int, Error>)>.makeStream()
        let completed = DispatchGroup()

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: producerCount) { producer in
                for index in 0..<tasksPerProducer {
                    let id = producer * tasksPerProducer + index
                    completed.enter()
                    let caller = Task {
                        try await executor.runTask {
                            detector.enter()
                            defer { detector.leave() }
                            counters[id].increment()
                            await Task.yield()
                            if id.isMultiple(of: 7) { throw OperationError.failed(id) }
                            return id
                        }
                    }
                    if id.isMultiple(of: 3) { caller.cancel() }
                    if id.isMultiple(of: 5) { executor.cancelAll() }
                    Task {
                        continuation.yield((id, await caller.result))
                        completed.leave()
                    }
                }
            }
            completed.notify(queue: .global()) { continuation.finish() }
        }

        var received = Set<Int>()
        for await (id, result) in outcomes {
            let inserted = received.insert(id).inserted
            #expect(inserted)
            switch result {
            case let .success(value):
                #expect(value == id)
                #expect(counters[id].value == 1)
            case let .failure(error):
                #expect(error is CancellationError || (error as? OperationError) == .failed(id))
            }
        }
        #expect(received == Set(0..<total))
        for counter in counters {
            #expect(counter.value <= 1)
        }

        let result = try await executor.runTask {
            detector.enter()
            defer { detector.leave() }
            return "still usable"
        }
        #expect(result == "still usable")
        #expect(detector.peak >= 1)
        if maxConcurrentTasks > 0 {
            #expect(detector.peak <= maxConcurrentTasks)
        }
    }

    /// Add tasks concurrently from many child tasks; the executor must run all
    /// of them exactly once with no lost updates and no crash.
    @Test func concurrentAddTaskRunsEveryTaskExactlyOnce() async {
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let a = TaskQueue()
        let b = TaskQueue()
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
        let a = TaskQueue()
        let b = TaskQueue()
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
    @Test(arguments: [0, 1, 3])
    func deinitWhileBusyDoesNotCrash(_ maxConcurrentTasks: Int) async {
        let runningCount = maxConcurrentTasks > 0 ? maxConcurrentTasks : 3
        let release = Gate()
        let started = (0..<runningCount).map { _ in Gate() }
        let finished = (0..<runningCount).map { _ in Gate() }
        let ranAfter = Flag()
        weak var releasedExecutor: TaskQueue?

        do {
            let executor = TaskQueue(maxConcurrentTasks: maxConcurrentTasks)
            releasedExecutor = executor
            for id in 0..<runningCount {
                executor.addTask {
                    started[id].open()
                    await release.wait()
                    #expect(Task.isCancelled)
                    finished[id].open()
                }
            }
            for gate in started { await gate.wait() }
            if maxConcurrentTasks > 0 {
                executor.addTask { ranAfter.set() }
            }
            // executor goes out of scope here -> deinit runs cancelAll() etc.
        }

        #expect(releasedExecutor == nil)
        release.open()
        for gate in finished { await gate.wait() }

        // Give cooperative scheduling a chance via an explicit yield-based barrier
        // rather than sleeping. Spin a bounded number of yields.
        await Self.drainCooperatively()

        // The task queued behind the blocked operations should not have
        // executed because deinit cancelled all pending work.
        #expect(ranAfter.isSet == false)
    }

    /// Deinitializing an idle (drained) executor must be safe and not crash.
    @Test func deinitWhileIdleDoesNotCrash() async {
        do {
            let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
        let executor = TaskQueue()
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
