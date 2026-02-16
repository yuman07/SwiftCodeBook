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
        case async(LazyTask<Void, Never>)
        case sync(LazyTask<Sendable, Never>, UnsafeContinuation<Void, Never>)
        case syncWithThrowing(LazyTask<Sendable, Error>, UnsafeContinuation<Void, Never>)
    }
    
    private let (stream, continuation) = AsyncStream<TaskItem>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        Task(executorPreference: globalConcurrentExecutor) { [weak self] in
            let emptyStream = AsyncStream<TaskItem>.makeStream()
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
    public func async(_ operation: @Sendable @escaping () async -> Void) -> AnyCancellable {
        let lazyTask = LazyTask(operation)
        continuation.yield(.async(lazyTask))
        let cancelToken = lazyTask.toAnyCancellable
        cancelBag.store(cancelToken)
        return cancelToken
    }
    
    public func sync<Value: Sendable>(_ operation: @Sendable @escaping () async -> Value) async -> Value {
        let lazyTask = LazyTask(operation)
        cancelBag.store(lazyTask.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.sync(LazyTask { await lazyTask.start().value }, $0))
        }
        return await lazyTask.start().value
    }
    
    public func syncWithThrowing<Value: Sendable>(_ operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        let lazyTask = LazyTask(operation)
        cancelBag.store(lazyTask.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.syncWithThrowing(LazyTask { try await lazyTask.start().value }, $0))
        }
        return try await lazyTask.start().value
    }
    
    public func cancelAll() {
        cancelBag.cancel()
    }
}

private final class LazyTask<Success: Sendable, Failure: Error>: Sendable {
    private let operation: @Sendable () async throws(Failure) -> Success
    private let state = OSAllocatedUnfairLock<(task: Task<Success, Failure>?, isCancelled: Bool)>(initialState: (nil, false))
    
    init(_ operation: @Sendable @escaping () async throws(Failure) -> Success) {
        self.operation = operation
    }
    
    deinit {
        cancel()
    }
    
    func cancel() {
        state.withLock { curState in
            curState.isCancelled = true
            curState.task?.cancel()
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable({ [weak self] in self?.cancel() })
    }
}

private extension LazyTask where Failure == Never {
    func start() -> Task<Success, Never> {
        state.withLock { curState in
            let task = curState.task ?? Task { await operation() }
            curState.task = task
            if curState.isCancelled {
                task.cancel()
            }
            return task
        }
    }
}

private extension LazyTask where Failure == Error {
    func start() -> Task<Success, Failure> {
        state.withLock { curState in
            let task = curState.task ?? Task { try await operation() }
            curState.task = task
            if curState.isCancelled {
                task.cancel()
            }
            return task
        }
    }
}
