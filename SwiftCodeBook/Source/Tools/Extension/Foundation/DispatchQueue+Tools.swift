//
//  DispatchQueue+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation
import os

public extension DispatchQueue {
    static var currentQueueLabel: String {
        String(cString: __dispatch_queue_get_label(nil))
    }
    
    static var isMainQueue: Bool {
        currentQueueLabel == DispatchQueue.main.label
    }
    
    static func dispatchToMainIfNeeded(_ operation: @escaping @MainActor () -> Void) {
        if Thread.isMainThread && isMainQueue {
            MainActor.assumeIsolated {
                operation()
            }
        } else {
            DispatchQueue.main.async {
                operation()
            }
        }
    }
    
    private static let tokenSet = OSAllocatedUnfairLock(initialState: Set<String>())
    static func runOnce(file: String = #file, line: Int = #line, function: String = #function, customKey: String? = nil, operation: (() -> Void)) {
        if tokenSet.withLock({ tokenSet in
            let token = customKey ?? "\(file)_\(line)_\(function)"
            if !tokenSet.contains(token) {
                tokenSet.insert(token)
                return true
            }
            return false
        }) {
            operation()
        }
    }
}
