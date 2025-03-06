//
//  MemoryCache.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/26.
//

import Foundation

// NSCache在Swift中直接使用很麻烦，因为要求其Key/value是class类型
// 这样的要求和Swift中推崇ValueType的设计相冲突，这里进行一个简单封装
public final class MemoryCache<Key: Hashable, Value>: @unchecked Sendable {
    private let cache = NSCache<KeyObject<Key>, ValueObject<Value>>()
    
    public init() {}
    
    public func value(forKey key: Key) -> Value? {
        cache.object(forKey: KeyObject(key))?.value
    }
    
    public func setValue(_ val: Value, forKey key: Key, cost g: Int = 0) {
        cache.setObject(ValueObject(val), forKey: KeyObject(key), cost: g)
    }
    
    public func removeValue(forKey key: Key) {
        cache.removeObject(forKey: KeyObject(key))
    }
    
    public func removeAllValues() {
        cache.removeAllObjects()
    }
    
    public var name: String {
        get { cache.name }
        set { cache.name = newValue }
    }
    
    public var totalCostLimit: Int {
        get { cache.totalCostLimit }
        set { cache.totalCostLimit = newValue }
    }
    
    public var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }
    
    public var evictsObjectsWithDiscardedContent: Bool {
        get { cache.evictsObjectsWithDiscardedContent }
        set { cache.evictsObjectsWithDiscardedContent = newValue }
    }
}

private final class KeyObject<Key: Hashable>: Hashable {
    private let key: Key
    
    init(_ key: Key) {
        self.key = key
    }
    
    static func == (lhs: KeyObject<Key>, rhs: KeyObject<Key>) -> Bool {
        lhs.key == rhs.key
    }
    
    func hash(into hasher: inout Hasher) {
        key.hash(into: &hasher)
    }
}

private final class ValueObject<Value> {
    let value: Value
    
    init(_ value: Value) {
        self.value = value
    }
}
