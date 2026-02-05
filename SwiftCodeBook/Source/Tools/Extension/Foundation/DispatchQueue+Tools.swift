//
//  DispatchQueue+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

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
    
    private static let onceLock = NSRecursiveLock()
    nonisolated(unsafe) private static var tokenSet = Set<String>()
    static func runOnce(file: String = #file, function: String = #function, line: Int = #line, block: (() -> Void)) {
        onceLock.withLock {
            let t = "\(file)_\(function)_\(line)"
            if !tokenSet.contains(t) {
                tokenSet.insert(t)
                block()
            }
        }
    }
}
