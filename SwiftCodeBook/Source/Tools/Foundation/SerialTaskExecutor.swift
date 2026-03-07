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
    private let (stream, continuation) = AsyncStream<LazyTask>.makeStream()
    private let cancelBag = CancelBag()
    
    public init(priority: TaskPriority? = nil) {
        let taskStream = stream
        Task(executorPreference: globalConcurrentExecutor, priority: priority) {
            for await task in taskStream {
                await task.start().value
            }
        }
    }
    
    deinit {
        continuation.finish()
    }
    
    @discardableResult
    public func addTask(_ operation: @Sendable @escaping () async -> Void) -> AnyCancellable {
        let lazyTask = LazyTask(operation)
        let token = lazyTask.toAnyCancellable
        cancelBag.store(token)
        continuation.yield(lazyTask)
        return token
    }
    
    public func cancelAll() {
        cancelBag.cancelAll()
    }
}

private final class LazyTask: Sendable {
    private let operation: @Sendable () async -> Void
    private let context = OSAllocatedUnfairLock<(task: Task<Void, Never>?, isCancelled: Bool)>(initialState: (nil, false))
    
    init(_ operation: @Sendable @escaping () async -> Void) {
        self.operation = operation
    }
    
    deinit {
        cancel()
    }
    
    private func cancel() {
        context.withLock { context in
            context.isCancelled = true
            context.task?.cancel()
        }
    }
    
    func start() -> Task<Void, Never> {
        context.withLock { context in
            let task = context.task ?? Task { await operation() }
            context.task = task
            if context.isCancelled { task.cancel() }
            return task
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable { [weak self] in self?.cancel() }
    }
}
