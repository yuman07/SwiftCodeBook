//
//  Atomic.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

@propertyWrapper
final class Atomic<T> {
    private let lock = ReadWriteLock()
    private var value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    var wrappedValue: T {
        get { lock.read { value } }
        set { lock.write { value = newValue } }
    }
    
    var projectedValue: Atomic<T> { self }
    
    init(wrappedValue: T) {
        value = wrappedValue
    }
    
    func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        try lock.read { try closure(value) }
    }
    
    func write(_ closure: (inout T) throws -> Void) rethrows {
        try lock.write { try closure(&value) }
    }
}
