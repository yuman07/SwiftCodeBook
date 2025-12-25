//
//  AsyncSemaphore.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/25.
//

import Foundation

public actor AsyncSemaphore {
    private struct Waiter {
        let id: UUID
        let continuation: UnsafeContinuation<Void, Error>
    }

    private var value: Int
    private var waiters = [Waiter]()

    public init(value: Int) {
        self.value = value
    }
    
    public func wait() async throws {
        value -= 1
        if value >= 0 {
            return
        }
        
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
        
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task {
                await cancel(id)
            }
        }
    }
    
    public nonisolated func signal() {
        Task {
            await release()
        }
    }
    
    private func release() {
        value += 1
        if let first = waiters.first {
            first.continuation.resume()
            waiters.removeFirst()
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters[index].continuation.resume(throwing: CancellationError())
        waiters.remove(at: index)
        release()
    }
}
