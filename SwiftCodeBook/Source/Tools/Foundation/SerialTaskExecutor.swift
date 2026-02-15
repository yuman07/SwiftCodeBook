//
//  SerialTaskExecutor.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/15.
//

import Combine
import Foundation

public final class SerialTaskExecutor: Sendable {
    private enum TaskItem {
        case async(Task<Void, Never>)
        case sync(Task<Sendable, Never>, UnsafeContinuation<Void, Never>)
        case syncWithThrowing(Task<Sendable, Error>, UnsafeContinuation<Void, Never>)
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
                    await task.value
                case let .sync(task, unsafeContinuation):
                    let _ = await task.value
                    unsafeContinuation.resume()
                case let .syncWithThrowing(task, unsafeContinuation):
                    let _ = await task.result
                    unsafeContinuation.resume()
                }
            }
        }
    }
    
    @discardableResult
    public func async(_ task: Task<Void, Never>) -> AnyCancellable {
        continuation.yield(.async(task))
        let cancelToken = task.toAnyCancellable
        cancelBag.store(cancelToken)
        return cancelToken
    }
    
    public func sync<Value: Sendable>(_ task: Task<Value, Never>) async -> Value {
        cancelBag.store(task.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.sync(Task { await task.value }, $0))
        }
        return await task.value
    }
    
    public func syncWithThrowing<Value: Sendable>(_ task: Task<Value, Error>) async throws -> Value {
        cancelBag.store(task.toAnyCancellable)
        await withUnsafeContinuation {
            continuation.yield(.syncWithThrowing(Task { try await task.value }, $0))
        }
        return try await task.value
    }
    
    public func cancelAll() {
        cancelBag.cancel()
    }
}
