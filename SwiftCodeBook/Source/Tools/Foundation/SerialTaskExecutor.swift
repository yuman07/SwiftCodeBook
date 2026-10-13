//
//  SerialTaskExecutor.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/15.
//

import Combine
import Foundation
import os

public final class SerialTaskExecutor: Sendable {
    private let (stream, continuation) = AsyncStream<TaskEntry>.makeStream()
    private let worker: Task<Void, Never>
    private let tasks = OSAllocatedUnfairLock(initialState: Set<TaskEntry>())

    public init(priority: TaskPriority? = nil) {
        worker = Task(priority: priority) { [stream, tasks] in
            for await entry in stream {
                defer { withExtendedLifetime(entry) {} }
                guard tasks.withLock({ $0.contains(entry) }) else {
                    entry.task.cancel()
                    continue
                }
                await entry.task.run()
                tasks.withLock { _ = $0.remove(entry) }
            }
        }
    }

    deinit {
        cancelAll()
        continuation.finish()
        worker.cancel()
    }

    @discardableResult
    public func addTask(_ operation: @Sendable @escaping () async -> Void) -> AnyCancellable {
        let task = LazyTask(operation)
        let token = task.toAnyCancellable
        enqueue(task)
        return token
    }

    public func runTask<Success: Sendable>(_ operation: @Sendable @escaping () async throws -> Success) async throws -> Success {
        let task = LazyTask(operation)
        return try await withTaskCancellationHandler {
            enqueue(task)
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

    private func enqueue(_ task: any QueuedTask) {
        let entry = TaskEntry(task: task)
        tasks.withLock { _ = $0.insert(entry) }
        continuation.yield(entry)
    }
}

private protocol QueuedTask: AnyObject, Sendable {
    func run() async
    func cancel()
}

private struct TaskEntry: Hashable, Sendable {
    let task: any QueuedTask

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
