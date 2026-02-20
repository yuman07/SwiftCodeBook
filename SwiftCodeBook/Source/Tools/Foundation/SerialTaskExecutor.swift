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
    public struct CancelToken: @unchecked Sendable {
        let token: AnyCancellable
    }
    
    @TaskLocal static private var isOnExecutor = false
    private let (stream, continuation) = AsyncStream<@Sendable () async -> Void>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        let taskStream = stream
        Task(executorPreference: globalConcurrentExecutor) {
            for await task in taskStream {
                await Self.$isOnExecutor.withValue(true) {
                    await task()
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
        let token = CancelToken(token: lazyTask.toAnyCancellable)
        continuation.yield { await lazyTask.start().value }
        cancelBag.store(token.token)
        return token
    }
    
    public func sync<T: Sendable>(_ operation: @Sendable @escaping () async -> T) async -> T {
        guard !Self.isOnExecutor else {
            fatalError("Attempting to synchronously execute a task on the same executor results in deadlock.")
        }
        
        let lazyTask = LazyTask(operation)
        cancelBag.store(lazyTask.toAnyCancellable)
        return await withUnsafeContinuation { cont in
            continuation.yield { await cont.resume(returning: lazyTask.start().value) }
        }
    }
    
    public func sync<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        guard !Self.isOnExecutor else {
            fatalError("Attempting to synchronously execute a task on the same executor results in deadlock.")
        }
        
        let lazyTask = LazyTask(operation)
        cancelBag.store(lazyTask.toAnyCancellable)
        return try await withUnsafeThrowingContinuation { cont in
            continuation.yield {
                do {
                    try await cont.resume(returning: lazyTask.start().value)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
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
        state.withLock { state in
            state.isCancelled = true
            state.task?.cancel()
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable { [weak self] in self?.cancel() }
    }
}

private extension LazyTask where Failure == Never {
    func start() -> Task<Success, Never> {
        state.withLock { state in
            let task = state.task ?? Task { await operation() }
            state.task = task
            if state.isCancelled { task.cancel() }
            return task
        }
    }
}

private extension LazyTask where Failure == Error {
    func start() -> Task<Success, Failure> {
        state.withLock { state in
            let task = state.task ?? Task { try await operation() }
            state.task = task
            if state.isCancelled { task.cancel() }
            return task
        }
    }
}
