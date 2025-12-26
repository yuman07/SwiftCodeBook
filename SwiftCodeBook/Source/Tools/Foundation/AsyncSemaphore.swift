//
//  AsyncSemaphore.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/25.
//

import Foundation

public actor AsyncSemaphore {
    private var value: UInt
    private var waiters = [UnsafeContinuation<Void, Never>]()
    
    public init(value: UInt) {
        self.value = value
    }
    
    public func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withUnsafeContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    public nonisolated func signal() {
        Task {
            await release()
        }
    }
    
    private func release() {
        value += 1
        while value > 0, let waiter = waiters.first {
            value -= 1
            waiters.removeFirst()
            waiter.resume()
        }
    }
}
