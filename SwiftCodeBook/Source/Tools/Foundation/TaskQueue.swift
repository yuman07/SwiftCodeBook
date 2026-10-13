//
//  TaskQueue.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/15.
//

import Combine
import Foundation
import os

public final class TaskQueue: Sendable {
    private let (stream, continuation) = AsyncStream<TaskEntry>.makeStream()
    private let worker: Task<Void, Never>
    private let tasks = OSAllocatedUnfairLock(initialState: Set<TaskEntry>())
    private let runningTasks = OSAllocatedUnfairLock(uncheckedState: Set<UnsafeCurrentTask>())

    public init(maxConcurrentTasks: Int = 1, priority: TaskPriority? = nil) {
        worker = Task(priority: priority) { [stream, tasks] in
            let run: @Sendable (TaskEntry) async -> Void = { entry in
                defer { withExtendedLifetime(entry) {} }
                guard tasks.withLock({ $0.contains(entry) }) else {
                    entry.task.cancel()
                    return
                }
                await entry.task.run()
                tasks.withLock { _ = $0.remove(entry) }
            }
            var iterator = stream.makeAsyncIterator()
            while true {
                let barrier: TaskEntry?
                if maxConcurrentTasks <= 0 {
                    barrier = await withDiscardingTaskGroup { group -> TaskEntry? in
                        while let entry = await iterator.next() {
                            if entry.isBarrier { return entry }
                            group.addTask { await run(entry) }
                        }
                        return nil
                    }
                } else {
                    barrier = await withTaskGroup(of: Void.self) { group -> TaskEntry? in
                        var inFlight = 0
                        while let entry = await iterator.next() {
                            if entry.isBarrier { return entry }
                            if inFlight == maxConcurrentTasks {
                                await group.next()
                                inFlight -= 1
                            }
                            group.addTask { await run(entry) }
                            inFlight += 1
                        }
                        return nil
                    }
                }
                guard let barrier else { break }
                await run(barrier)
            }
        }
    }

    deinit {
        cancelAll()
        continuation.finish()
        worker.cancel()
    }

    @discardableResult
    public func addTask(isBarrier: Bool = false, _ operation: @Sendable @escaping () async -> Void) -> AnyCancellable {
        let task = makeTask(operation)
        let token = task.toAnyCancellable
        enqueue(task, isBarrier: isBarrier)
        return token
    }

    public func runTask<Success: Sendable>(isBarrier: Bool = false, _ operation: @Sendable @escaping () async throws -> Success) async throws -> Success {
        try Task.checkCancellation()
        let isReentrant = withUnsafeCurrentTask { current in
            guard let current else { return false }
            return runningTasks.withLockUnchecked { $0.contains(current) }
        }
        precondition(!isReentrant, "TaskQueue.runTask cannot be awaited from an operation running on the same queue.")
        let task = makeTask(operation)
        return try await withTaskCancellationHandler {
            enqueue(task, isBarrier: isBarrier)
            return try await task.waitForCompletion()
        } onCancel: {
            task.cancel()
        }
    }

    public func cancelAll() {
        let allTasks = tasks.withLock { tasks in
            defer { tasks.removeAll() }
            return tasks
        }
        for entry in allTasks { entry.task.cancel() }
    }

    private func enqueue(_ task: any QueuedTask, isBarrier: Bool) {
        let entry = TaskEntry(task: task, isBarrier: isBarrier)
        tasks.withLock { _ = $0.insert(entry) }
        continuation.yield(entry)
    }

    private func makeTask<Success: Sendable>(_ operation: @Sendable @escaping () async throws -> Success) -> LazyTask<Success> {
        LazyTask { [runningTasks] in
            try await withUnsafeCurrentTask { task in
                if let task { runningTasks.withLockUnchecked { _ = $0.insert(task) } }
                defer {
                    if let task { runningTasks.withLockUnchecked { _ = $0.remove(task) } }
                }
                return try await operation()
            }
        }
    }
}

private protocol QueuedTask: AnyObject, Sendable {
    func run() async
    func cancel()
}

private struct TaskEntry: Hashable, Sendable {
    let task: any QueuedTask
    let isBarrier: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.task === rhs.task
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(task))
    }
}

private final class LazyTask<Success: Sendable>: QueuedTask {
    private typealias Operation = @Sendable () async throws -> Success
    private let context: OSAllocatedUnfairLock<Context>

    private struct Context {
        var operation: Operation?
        var task: Task<Success, Error>?
        var result: Result<Success, Error>?
        var continuation: UnsafeContinuation<Success, Error>?
        var token: AnyCancellable?
    }

    init(_ operation: @Sendable @escaping () async throws -> Success) {
        context = OSAllocatedUnfairLock(uncheckedState: Context(operation: operation))
    }
    
    deinit {
        cancel()
    }

    var toAnyCancellable: AnyCancellable {
        context.withLockUnchecked { context in
            if let token = context.token { return token }
            let token = AnyCancellable { [weak self] in self?.cancel() }
            context.token = token
            return token
        }
    }
    
    func cancel() {
        guard let (task, operation) = context.withLock({ context -> (Task<Success, Error>?, Operation?)? in
            guard context.result == nil else { return nil }
            defer { context.operation = nil }
            return (context.task, context.operation)
        }) else { return }
        defer { withExtendedLifetime(operation) {} }
        if let task {
            task.cancel()
        } else {
            finish(.failure(CancellationError()))
        }
    }

    func run() async {
        guard let task = start() else { return }
        finish(await task.result)
    }

    private func start() -> Task<Success, Error>? {
        let (task, operation) = context.withLock { context -> (Task<Success, Error>?, Operation?) in
            guard let operation = context.operation else {
                return (context.task, nil)
            }
            let task = Task { try await operation() }
            context.task = task
            context.operation = nil
            return (task, operation)
        }
        defer { withExtendedLifetime(operation) {} }
        return task
    }

    func waitForCompletion() async throws -> Success {
        try await withUnsafeThrowingContinuation { continuation in
            let result = context.withLock { context in
                if context.result == nil {
                    context.continuation = continuation
                }
                return context.result
            }
            if let result { continuation.resume(with: result) }
        }
    }

    private func finish(_ result: Result<Success, Error>) {
        let continuation = context.withLock { context -> UnsafeContinuation<Success, Error>? in
            guard context.result == nil else { return nil }
            context.result = result
            defer { context.continuation = nil }
            return context.continuation
        }
        continuation?.resume(with: result)
    }
}
