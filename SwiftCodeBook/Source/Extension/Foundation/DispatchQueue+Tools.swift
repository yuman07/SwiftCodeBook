//
//  DispatchQueue+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension DispatchQueue {
    static var isMainQueue: Bool {
        String(cString: __dispatch_queue_get_label(nil)) == DispatchQueue.main.label
    }
    
    static func runInMainQueue(block: @escaping (() -> Void)) {
        if Thread.isMainThread && isMainQueue {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    private static var onceSet = Set<String>()
    private static let onceLock = UnfairLock()
    static func runOnce(token: String? = nil, block: (() -> Void)) {
        let useToken = token ?? "\(#file)+\(#function)+\(#line)"
        
        onceLock.lock()
        defer { onceLock.unlock() }
        
        if !onceSet.contains(useToken) {
            onceSet.insert(useToken)
            block()
        }
    }
}
