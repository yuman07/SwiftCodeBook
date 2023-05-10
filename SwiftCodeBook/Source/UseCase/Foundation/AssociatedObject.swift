//
//  AssociatedObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/4.
//

import Foundation

// must be 'class', not 'struct'
final class AssociatedObjectItem {
    init() {
        setupA()
    }
}

extension AssociatedObjectItem {
    private enum AssociatedKeys {
        static var age = "age"
        static var block = "block"
        static var contentLock = "contentLock"
        static var content = "content"
    }
    
    // 某些情况下我们需要AssociatedObj是线程安全的，即加锁
    // 但由于锁本身的创建也需要线程安全，因此我目前想到的方法是新增一个setup方法
    // 该方法内去创建锁，必须保证该方法的调用早于需要线程安全的变量使用
    func setupA() {
        _ = contentLock
    }
    
    var age: Int {
        get { objc_getAssociatedObject(self, &AssociatedKeys.age) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &AssociatedKeys.age, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var block: (() -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.block) as? () -> Void }
        set { objc_setAssociatedObject(self, &AssociatedKeys.block, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var contentLock: NSLock {
        objc_getAssociatedObject(self, &AssociatedKeys.contentLock) as? NSLock ?? {
            let lock = NSLock()
            objc_setAssociatedObject(self, &AssociatedKeys.contentLock, lock, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return lock
        }()
    }
    
    var content: String {
        get { contentLock.withLock { objc_getAssociatedObject(self, &AssociatedKeys.content) as? String ?? "" } }
        set { contentLock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.content, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) } }
    }
}
