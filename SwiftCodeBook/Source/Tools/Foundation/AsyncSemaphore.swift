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
        let priority: TaskPriority
        let continuation: UnsafeContinuation<Void, Error>
    }

    private var value: Int
    private var waiters = [Waiter]()

    public init(value: Int) {
        self.value = value
    }
    
    public func wait() async throws {
        if value > 0 {
            value -= 1
            return
        }
        
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { continuation in
                let waiter = Waiter(id: id, priority: Task.currentPriority, continuation: continuation)
                waiters.append(waiter)
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
        guard let maxPriority = waiters.map(\.priority).max(),
              let index = waiters.firstIndex(where: { $0.priority == maxPriority }) else {
            return
        }
        
        waiters[index].continuation.resume()
        waiters.remove(at: index)
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters[index].continuation.resume(throwing: CancellationError())
        waiters.remove(at: index)
        value += 1
    }
}
