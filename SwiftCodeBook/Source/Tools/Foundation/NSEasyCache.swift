//
//  NSEasyCache.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/26.
//

import Foundation

// NSCache在Swift中直接使用很麻烦，因为要求其Key是NSObject子类，且Value是class类型。
// 这样的要求和Swift中推崇ValueType的设计相冲突，这里进行一个简单封装
public final class NSEasyCache {
    private var nsCacheDelegate: NSCacheDelegate?
    private let cache = NSCache<KeyObject, ValueObject>()
    
    public init() {}
    
    public func value(forKey key: AnyHashable) -> Any? {
        cache.object(forKey: KeyObject(key))?.value
    }
    
    public func setValue(_ val: Any, forKey key: AnyHashable, cost g: Int = 0) {
        cache.setObject(ValueObject(val), forKey: KeyObject(key), cost: g)
    }
    
    public func removeValue(forKey key: AnyHashable) {
        cache.removeObject(forKey: KeyObject(key))
    }
    
    public func removeAllValues() {
        cache.removeAllObjects()
    }
    
    public var name: String {
        get { cache.name }
        set { cache.name = newValue }
    }
    
    public var delegate: (any NSEasyCacheDelegate)? {
        get { (nsCacheDelegate as? NSCacheDelegateObject)?.delegate }
        set {
            guard let newValue else {
                nsCacheDelegate = nil
                cache.delegate = nil
                return
            }
            nsCacheDelegate = NSCacheDelegateObject(easyCache: self, delegate: newValue)
            cache.delegate = nsCacheDelegate
        }
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

public protocol NSEasyCacheDelegate: AnyObject {
    func cache(_ cache: NSEasyCache, willEvictValue val: Any)
}

@available(*, unavailable)
extension NSEasyCache: @unchecked Sendable {}

private final class KeyObject: NSObject {
    let key: AnyHashable
    
    init(_ key: AnyHashable) {
        self.key = key
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        (object as? KeyObject)?.key == key
    }
    
    override var hash: Int {
        key.hashValue
    }
}

private final class ValueObject {
    var value: Any
    
    init(_ value: Any) {
        self.value = value
    }
}

private final class NSCacheDelegateObject: NSObject, NSCacheDelegate {
    private weak var easyCache: NSEasyCache?
    weak var delegate: NSEasyCacheDelegate?
    
    init(easyCache: NSEasyCache?, delegate: NSEasyCacheDelegate?) {
        self.easyCache = easyCache
        self.delegate = delegate
    }
    
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        guard let easyCache, let val = obj as? ValueObject else { return }
        delegate?.cache(easyCache, willEvictValue: val.value)
    }
}
