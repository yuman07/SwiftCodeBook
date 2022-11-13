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
    
    static func mainCurrentOrAsync(block: @escaping (() -> Void)) {
        if Thread.isMainThread && isMainQueue {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}
