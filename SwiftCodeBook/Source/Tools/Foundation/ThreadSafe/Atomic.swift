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
        get { lock.around { value } }
        set { lock.around { value = newValue } }
    }
    
    public var projectedValue: Atomic<T> { self }
    
    public func lock(_ closure: (inout T) throws -> Void) rethrows {
        try lock.around { try closure(&value) }
    }
    
    public func lock<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        try lock.around { try closure(&value) }
    }
}
