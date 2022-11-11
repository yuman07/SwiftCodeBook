//
//  NSLock+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

extension NSLock {
    func around<T>(_ block: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try block()
    }
    
    func around(_ block: () throws -> Void) rethrows {
        lock(); defer { unlock() }
        try block()
    }
}
