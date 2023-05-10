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
