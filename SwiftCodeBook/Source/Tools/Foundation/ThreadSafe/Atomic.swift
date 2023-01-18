//
//  Atomic.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

@propertyWrapper
public final class Atomic<T> {
    private let lock = NSLock()
    private var value: T
    
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: T {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
    
    public var projectedValue: Atomic<T> { self }
    
    public func withLock<U>(_ block: (inout T) throws -> U) rethrows -> U {
        try lock.withLock { try block(&value) }
    }
}
