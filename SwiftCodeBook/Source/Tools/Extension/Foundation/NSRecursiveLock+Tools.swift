//
//  NSRecursiveLock+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/1/18.
//

import Foundation

public extension NSRecursiveLock {
    func around(_ block: () throws -> Void) rethrows {
        lock()
        defer { unlock() }
        try block()
    }
    
    func around<T>(_ block: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try block()
    }
}
