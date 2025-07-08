//
//  MemoryCache.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/26.
//

import Combine
import UIKit

// NSCache在Swift中直接使用很麻烦，因为要求其Key/value是class类型
// 这样的要求和Swift中推崇ValueType的设计相冲突，这里进行一个简单封装
public final class MemoryCache<Key: Hashable, Value>: @unchecked Sendable {
    private let cache = NSCache<KeyObject<Key>, ValueObject<Value>>()
    private var cancellable: AnyCancellable?
    
    public init() {
        cancellable = NotificationCenter
            .default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                removeAllValues()
            }
    }
    
    public func value(forKey key: Key) -> Value? {
        cache.object(forKey: KeyObject(key))?.value
    }
    
    public func setValue(_ value: Value, forKey key: Key, cost g: Int = 0) {
        cache.setObject(ValueObject(value), forKey: KeyObject(key), cost: g)
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
