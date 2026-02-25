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
    
    @TaskLocal private static var currentExecutorID: ObjectIdentifier?
    private let (stream, continuation) = AsyncStream<LazyTask>.makeStream()
    private let cancelBag = CancelBag()
    
    public init() {
        let taskStream = stream
        let selfID = ObjectIdentifier(self)
        Task(executorPreference: globalConcurrentExecutor) {
            for await task in taskStream {
                await Self.$currentExecutorID.withValue(selfID) {
                    await task.start().value
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
        cancelBag.store(token.token)
        continuation.yield(lazyTask)
        return token
    }
    
    public func sync<T: Sendable>(_ operation: @Sendable @escaping () async -> T) async -> T {
        guard Self.currentExecutorID != ObjectIdentifier(self) else {
            fatalError("Attempting to synchronously execute a task on the same executor results in deadlock.")
        }
        
        return await withUnsafeContinuation { cont in
            let lazyTask = LazyTask { await cont.resume(returning: operation()) }
            cancelBag.store(lazyTask.toAnyCancellable)
            continuation.yield(lazyTask)
        }
    }
    
    public func sync<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) async throws -> T {
        guard Self.currentExecutorID != ObjectIdentifier(self) else {
            fatalError("Attempting to synchronously execute a task on the same executor results in deadlock.")
        }
        
        return try await withUnsafeThrowingContinuation { cont in
            let lazyTask = LazyTask {
                do {
                    try await cont.resume(returning: operation())
                } catch {
                    cont.resume(throwing: error)
                }
            }
            cancelBag.store(lazyTask.toAnyCancellable)
            continuation.yield(lazyTask)
        }
    }
    
    public func cancelAll() {
        cancelBag.cancelAll()
    }
    
    public func cancel(_ cancelToken: CancelToken) {
        cancelToken.token.cancel()
    }
}

private final class LazyTask: Sendable {
    private let operation: @Sendable () async -> Void
    private let state = OSAllocatedUnfairLock<(task: Task<Void, Never>?, isCancelled: Bool)>(initialState: (nil, false))
    
    init(_ operation: @Sendable @escaping () async -> Void) {
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
    
    func start() -> Task<Void, Never> {
        state.withLock { state in
            let task = state.task ?? Task { await operation() }
            state.task = task
            if state.isCancelled { task.cancel() }
            return task
        }
    }
    
    var toAnyCancellable: AnyCancellable {
        AnyCancellable { [weak self] in self?.cancel() }
    }
}
