//
//  InFlightOperationCache.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/24.
//

import Foundation

// 用于如request url时，如果当前已经有一样的url request在飞，则不发送此次request而复用当前在飞的request的结果
public actor InFlightOperationCache<Key: Hashable, Value: Sendable> {
    private struct Entry: Sendable {
        let task: Task<Value, Error>
        var refIdSet: Set<String>
    }
    
    private var inflight = [Key: Entry]()
    
    public init() {}
    
    public func run(reuseKey key: Key, operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        let task: Task<Value, Error>
        let refId = UUID().uuidString
        
        if var entry = inflight[key] {
            entry.refIdSet.insert(refId)
            inflight[key] = entry
            task = entry.task
        } else {
            let newTask = Task { try await operation() }
            inflight[key] = Entry(task: newTask, refIdSet: [refId])
            task = newTask
        }
        
        return try await awaitTaskValue(key: key, task: task, refId: refId)
    }
    
    private func awaitTaskValue(key: Key, task: Task<Value, Error>, refId: String) async throws -> Value {
        try await withTaskCancellationHandler {
            defer { finishTask(for: key, refId: refId, isCancelled: false) }
            return try await task.value
        } onCancel: {
            Task {
                await finishTask(for: key, refId: refId, isCancelled: true)
            }
        }
    }
    
    private func finishTask(for key: Key, refId: String, isCancelled: Bool) {
        guard var entry = inflight[key], entry.refIdSet.remove(refId) != nil else { return }
        if !entry.refIdSet.isEmpty {
            inflight[key] = entry
        } else {
            inflight[key] = nil
            if isCancelled {
                entry.task.cancel()
            }
        }
    }
}
