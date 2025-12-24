//
//  InFlightOperationCache.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/24.
//

import Foundation

// 用于如request url时，如果当前已经有一样的url request在飞，则不发送此次request而复用当前在飞的request的结果
public actor InFlightOperationCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry: Sendable {
        let task: Task<Value, Error>
        var refCount: Int
    }

    private var inflight = [Key: Entry]()

    public init() {}

    public func run(_ key: Key, operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        let task: Task<Value, Error>
        
        if var entry = inflight[key] {
            entry.refCount += 1
            inflight[key] = entry
            task = entry.task
        } else {
            let newTask = Task(priority: Task.currentPriority) {
                try await operation()
            }
            inflight[key] = Entry(task: newTask, refCount: 1)
            task = newTask
        }
        
        return try await awaitTaskValue(key: key, task: task)
    }

    private func awaitTaskValue(key: Key, task: Task<Value, Error>) async throws -> Value {
        try await withTaskCancellationHandler {
            defer { finishTask(for: key) }
            try Task.checkCancellation()
            let value = try await task.value
            try Task.checkCancellation()
            return value
        } onCancel: {}
    }

    private func finishTask(for key: Key) {
        guard var entry = inflight[key] else { return }
        entry.refCount -= 1
        if entry.refCount > 0 {
            inflight[key] = entry
        } else {
            inflight[key] = nil
            if Task.isCancelled {
                entry.task.cancel()
            }
        }
    }
}
