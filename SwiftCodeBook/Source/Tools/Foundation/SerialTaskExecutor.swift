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
    private enum TaskItem: Sendable {
        case async(LazyTask<Void>)
        case sync(LazyTask<Sendable>, UnsafeContinuation<Void, Never>)
        case syncWithThrowing(LazyThrowingTask<Sendable>, UnsafeContinuation<Void, Never>)
    }
    
    private let (stream, continuation) = AsyncStream<TaskItem>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        let emptyStream = AsyncStream<TaskItem>.makeStream()
        Task(executorPreference: globalConcurrentExecutor) { [weak self] in
            for await item in self?.stream ?? emptyStream.stream {
                guard self != nil else { return }
                switch item {
                case let .async(task):
                    await task.start().value
                case let .sync(task, unsafeContinuation):
                    let _ = await task.start().value
                    unsafeContinuation.resume()
                case let .syncWithThrowing(task, unsafeContinuation):
                    let _ = await task.start().result
                    unsafeContinuation.resume()
                }
            }
        }
    }
    
    @discardableResult
    public func async(_ operation: @escaping () async -> Void) -> AnyCancellable {
        let lazyTask = LazyTask(operation)
        continuation.yield(.async(lazyTask))
        let cancelToken = lazyTask.toAnyCancellable
        cancelBag.store(cancelToken)
        return cancelToken
    }
    
    public func sync<Value: Sendable>(_ operation: @escaping () async -> Value) async -> Value {
        let lazyTask = LazyTask(operation)
        let sendableLazyTask = LazyTask<Sendable> { await lazyTask.start().value }
        cancelBag.store(lazyTask.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.sync(sendableLazyTask, $0))
        }
        return await lazyTask.start().value
    }
    
    public func syncWithThrowing<Value: Sendable>(_ operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        let lazyTask = LazyThrowingTask(operation)
        let sendableLazyTask = LazyThrowingTask<Sendable> { try await lazyTask.start().value }
        cancelBag.store(lazyTask.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.syncWithThrowing(sendableLazyTask, $0))
        }
        return try await lazyTask.start().value
    }
    
    public func cancelAll() {
        cancelBag.cancel()
    }
}

private final class LazyTask<Success>: @unchecked Sendable where Success: Sendable {
    let operation: () async -> Success
    var isCancelled = false
    var task: Task<Success, Never>?
    let lock = OSAllocatedUnfairLock()
    
    init(_ operation: @escaping () async -> Success) {
        self.operation = operation
    }
    
    deinit {
        cancel()
    }
    
    func start() -> Task<Success, Never> {
        lock.withLock {
            let realTask = task ?? Task() { await operation() }
            task = realTask
            if isCancelled {
                realTask.cancel()
            }
            return realTask
        }
    }
    
    func cancel() {
        lock.withLock {
            isCancelled = true
            task?.cancel()
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable({ [weak self] in self?.cancel() })
    }
}

private final class LazyThrowingTask<Success>: @unchecked Sendable where Success: Sendable {
    let operation: () async throws -> Success
    var isCancelled = false
    var task: Task<Success, Error>?
    let lock = OSAllocatedUnfairLock()
    
    init(_ operation: @escaping () async throws -> Success) {
        self.operation = operation
    }
    
    deinit {
        cancel()
    }
    
    func start() -> Task<Success, Error> {
        lock.withLock {
            let realTask = task ?? Task() { try await operation() }
            task = realTask
            if isCancelled {
                realTask.cancel()
            }
            return realTask
        }
    }
    
    func cancel() {
        lock.withLock {
            isCancelled = true
            task?.cancel()
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable({ [weak self] in self?.cancel() })
    }
}
