//
//  AsyncSemaphore.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/25.
//

import Foundation

public actor AsyncSemaphore {
    private var value: UInt
    private var waiters = [Waiter]()
    private var nextID: UInt64 = 0

    private struct Waiter {
        let id: UInt64
        let continuation: UnsafeContinuation<Void, Error>
    }

    public init(value: UInt) {
        self.value = value
    }

    /// Waits for a permit. This wait is NOT interrupted by cancellation
    /// (classic semaphore semantics).
    public func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        let id = makeID()
        // The continuation is only ever resumed normally for this path, so the
        // `try?` never actually swallows an error.
        try? await withUnsafeThrowingContinuation { continuation in
            waiters.append(Waiter(id: id, continuation: continuation))
        }
    }

    /// Waits for a permit, throwing `CancellationError` if the task is cancelled
    /// before a permit becomes available. On cancellation the waiter is removed
    /// without consuming a permit.
    public func waitUnlessCancelled() async throws {
        if value > 0 {
            value -= 1
            return
        }

        let id = makeID()
        try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    public nonisolated func signal() {
        Task {
            await release()
        }
    }

    private func makeID() -> UInt64 {
        defer { nextID &+= 1 }
        return nextID
    }

    private func release() {
        value += 1
        while value > 0, !waiters.isEmpty {
            value -= 1
            waiters.removeFirst().continuation.resume()
        }
    }

    private func cancelWaiter(id: UInt64) {
        // If not found, the waiter was already resumed by `release()` — nothing to do.
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
