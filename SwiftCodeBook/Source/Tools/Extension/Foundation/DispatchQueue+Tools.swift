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
    
    static func mainCurrentOrAsync(block: @escaping (() -> Void)) {
        if Thread.isMainThread && isMainQueue {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    private static let onceLock = NSRecursiveLock()
    private static var tokenSet = Set<String>()
    static func runOnce(file: String = #file, function: String = #function, line: Int = #line, block: (() -> Void)) {
        onceLock.lock()
        defer { onceLock.unlock() }
        
        let t = "\(file)_\(function)_\(line)"
        if !tokenSet.contains(t) {
            tokenSet.insert(t)
            block()
        }
    }
}
