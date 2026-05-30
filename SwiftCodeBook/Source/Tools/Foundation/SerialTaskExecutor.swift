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
    private let worker: Task<Void, Never>
    private let tokensMap = OSAllocatedUnfairLock(uncheckedState: [LazyTask: AnyCancellable]())

    public init(priority: TaskPriority? = nil) {
        let thisStream = stream
        let thisTokensMap = tokensMap
        worker = Task(executorPreference: globalConcurrentExecutor, priority: priority) {
            for await task in thisStream {
                await task.start()?.value
                thisTokensMap.withLockUnchecked { $0[task] = nil }
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
        tokensMap.withLockUnchecked { $0[task] = token }
        continuation.yield(task)
        return token
    }

    public func cancelAll() {
        let allTokens = tokensMap.withLockUnchecked { dict in
            defer { dict.removeAll() }
            return Array(dict.values)
        }
        for token in allTokens { token.cancel() }
    }
}

private final class LazyTask: Sendable, Hashable {
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
    
    func start() -> Task<Void, Never>? {
        context.withLock { context in
            if context.task == nil && context.isCancelled {
                return nil
            }
            let task = context.task ?? Task { await operation() }
            context.task = task
            if context.isCancelled { task.cancel() }
            return task
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable { [weak self] in self?.cancel() }
    }

    static func == (lhs: LazyTask, rhs: LazyTask) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self)) 
    }
}
