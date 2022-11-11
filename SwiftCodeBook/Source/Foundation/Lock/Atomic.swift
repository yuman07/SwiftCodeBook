//
//  Atomic.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/11.
//

import Foundation

@propertyWrapper
final class Atomic<T> {
    private let lock = NSLock()
    private var value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    var wrappedValue: T {
        get { lock.around { value } }
        set { lock.around { value = newValue } }
    }
    
    var projectedValue: Atomic<T> { self }
    
    init(wrappedValue: T) {
        value = wrappedValue
    }
    
    func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        try lock.around { try closure(value) }
    }
    
    @discardableResult
    func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        try lock.around { try closure(&value) }
    }
}
