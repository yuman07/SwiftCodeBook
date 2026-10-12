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
    private let (stream, continuation) = AsyncStream<any QueuedTask>.makeStream()
    private let worker: Task<Void, Never>
    private let tasks = OSAllocatedUnfairLock(initialState: [any QueuedTask]())

    public init(priority: TaskPriority? = nil) {
        let thisStream = stream
        let thisTasks = tasks
        worker = Task(priority: priority) {
            for await task in thisStream {
                await task.run()
                thisTasks.withLock { tasks in
                    tasks.removeAll { $0 === task }
                }
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
        for task in allTasks { task.cancel() }
    }

    private func enqueue(_ task: any QueuedTask) {
        tasks.withLock { $0.append(task) }
        continuation.yield(task)
    }
}

private protocol QueuedTask: AnyObject, Sendable {
    func run() async
    func cancel()
}

private final class LazyTask<Success: Sendable>: QueuedTask {
    private let operation: @Sendable () async throws -> Success
    private let context = OSAllocatedUnfairLock(uncheckedState: Context())

    private struct Context {
        var task: Task<Success, Error>?
        var isCancelled = false
        var result: Result<Success, Error>?
        var continuation: CheckedContinuation<Success, Error>?
        var token: AnyCancellable?
    }

    init(_ operation: @Sendable @escaping () async throws -> Success) {
        self.operation = operation
    }
    
    deinit {
        cancel()
    }

    var toAnyCancellable: AnyCancellable {
        context.withLockUnchecked { context in
            if let token = context.token { return token }
            let token = AnyCancellable { [weak self] in self?.cancel() }
            // Retain the token so discarding addTask's return value does not cancel work.
            context.token = token
            return token
        }
    }
    
    func cancel() {
        let task = context.withLock { context in
            context.isCancelled = true
            return context.task
        }
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
        context.withLock { context in
            if context.task == nil && context.isCancelled {
                return nil
            }
            let task = context.task ?? Task { try await operation() }
            context.task = task
            return task
        }
    }

    func waitForCompletion() async throws -> Success {
        try await withCheckedThrowingContinuation { continuation in
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
        let continuation = context.withLock { context -> CheckedContinuation<Success, Error>? in
            guard context.result == nil else { return nil }
            context.result = result
            defer { context.continuation = nil }
            return context.continuation
        }
        continuation?.resume(with: result)
    }
}
