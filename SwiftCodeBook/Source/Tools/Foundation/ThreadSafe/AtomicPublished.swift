//
//  AtomicPublished.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/16.
//

import Combine
import Foundation

@propertyWrapper
public final class AtomicPublished<T> {
    private let lock = NSRecursiveLock()
    @Published private var value: T
    
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: T {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
    
    public var projectedValue: AnyPublisher<T, Never> { $value.eraseToAnyPublisher() }
}
