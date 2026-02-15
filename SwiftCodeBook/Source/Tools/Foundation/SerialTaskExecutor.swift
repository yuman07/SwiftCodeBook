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
        case sync(Task<Sendable, Never>, UnsafeContinuation<Sendable, Never>)
        case syncWithThrowing(Task<Sendable, Error>, UnsafeContinuation<Sendable, Error>)
    }
    
    private let (stream, continuation) = AsyncStream<TaskItem>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        Task(executorPreference: globalConcurrentExecutor) {
            for await item in self.stream {
                switch item {
                case let .async(task):
                    await task.value
                case let .sync(task, unsafeContinuation):
                    await unsafeContinuation.resume(returning: task.value)
                case let .syncWithThrowing(task, unsafeContinuation):
                    do {
                        try await unsafeContinuation.resume(returning: task.value)
                    } catch {
                        unsafeContinuation.resume(throwing: error)
                    }
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
    
    public func sync(_ task: Task<Sendable, Never>) async -> Sendable {
        cancelBag.store(task.toAnyCancellable)
        return await withUnsafeContinuation {
            continuation.yield(.sync(task, $0))
        }
    }
    
    public func syncWithThrowing(_ task: Task<Sendable, any Error>) async throws -> Sendable {
        cancelBag.store(task.toAnyCancellable)
        return try await withUnsafeThrowingContinuation {
            continuation.yield(.syncWithThrowing(task, $0))
        }
    }
    
    public func cancelAll() {
        cancelBag.cancel()
    }
}
