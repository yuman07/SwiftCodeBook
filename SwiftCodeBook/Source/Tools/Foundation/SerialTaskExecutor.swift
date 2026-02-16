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
    public struct CancelToken: @unchecked Sendable, Hashable {
        let token: AnyCancellable
    }
    
    private enum TaskItem: Sendable {
        case async(LazyTask<Void, Never>, CancelToken)
        case sync(LazyTask<Sendable, Never>, UnsafeContinuation<Void, Never>, CancelToken)
        case syncWithThrowing(LazyTask<Sendable, Error>, UnsafeContinuation<Void, Never>, CancelToken)
    }
    
    private let (stream, continuation) = AsyncStream<TaskItem>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        let taskStream = stream
        let bag = cancelBag
        Task(executorPreference: globalConcurrentExecutor) {
            for await item in taskStream {
                switch item {
                case let .async(task, cancelToken):
                    await task.start().value
                    bag.cancel(cancelToken.token)
                case let .sync(task, unsafeContinuation, cancelToken):
                    let _ = await task.start().value
                    bag.cancel(cancelToken.token)
                    unsafeContinuation.resume()
                case let .syncWithThrowing(task, unsafeContinuation, cancelToken):
                    let _ = await task.start().result
                    bag.cancel(cancelToken.token)
                    unsafeContinuation.resume()
                }
            }
        }
    }
    
    deinit {
        continuation.finish()
    }
    
    @discardableResult
    public func async(_ operation: @Sendable @escaping () async -> Void) -> CancelToken {
        let lazyTask = LazyTask(operation)
        let anyCancellable = lazyTask.toAnyCancellable
        let cancelToken = CancelToken(token: anyCancellable)
        continuation.yield(.async(lazyTask, cancelToken))
        cancelBag.store(anyCancellable)
        return cancelToken
    }
    
    public func sync<Value: Sendable>(_ operation: @Sendable @escaping () async -> Value) async -> Value {
        let lazyTask = LazyTask(operation)
        let anyCancellable = lazyTask.toAnyCancellable
        let cancelToken = CancelToken(token: anyCancellable)
        cancelBag.store(anyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.sync(LazyTask { await lazyTask.start().value }, $0, cancelToken))
        }
        return await lazyTask.start().value
    }
    
    public func syncWithThrowing<Value: Sendable>(_ operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        let lazyTask = LazyTask(operation)
        let anyCancellable = lazyTask.toAnyCancellable
        let cancelToken = CancelToken(token: anyCancellable)
        cancelBag.store(anyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.syncWithThrowing(LazyTask { try await lazyTask.start().value }, $0, cancelToken))
        }
        return try await lazyTask.start().value
    }
    
    public func cancelAll() {
        cancelBag.cancelAll()
    }
    
    public func cancel(_ cancelToken: CancelToken) {
        cancelBag.cancel(cancelToken.token)
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
    
    private func cancel() {
        state.withLock { curState in
            curState.isCancelled = true
            curState.task?.cancel()
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable { [weak self] in self?.cancel() }
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
