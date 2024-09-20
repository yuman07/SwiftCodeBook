//
//  AssociatedObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/4.
//

import Foundation
import os

// 必须使用 'class' 而不是 'struct'
// 尽管'struct'可以通过编译，但实际set时无效
final class AssociatedObjectItem {
    init() {
        // 保证content.objc_setAssociatedObject的过程是非多线程的
        _ = content
    }
}

extension AssociatedObjectItem {
    // https://github.com/atrick/swift-evolution/blob/diagnose-implicit-raw-bitwise/proposals/nnnn-implicit-raw-bitwise-conversion.md#associated-object-string-keys
    private enum AssociatedKeys {
        static var age: Void?
        static var block: Void?
        static var content: Void?
    }
    
    var age: Int {
        get { objc_getAssociatedObject(self, &AssociatedKeys.age) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &AssociatedKeys.age, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var block: (() -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.block) as? () -> Void }
        set { objc_setAssociatedObject(self, &AssociatedKeys.block, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // 有些时候我们需要AssociatedObject是线程安全的，这时可以这样写
    // 但注意一定要在该class init时去获取一下该obj，即保证objc_setAssociatedObject的过程是非多线程的
    var content: OSAllocatedUnfairLock<String> {
        objc_getAssociatedObject(self, &AssociatedKeys.content) as? OSAllocatedUnfairLock<String> ?? {
            let content = OSAllocatedUnfairLock(initialState: "")
            objc_setAssociatedObject(self, &AssociatedKeys.content, content, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return content
        }()
    }
}

// 除了能对class增加AssociatedObject，其实AnyObject的Protocol也可以
protocol SomeObjectProtocol: AnyObject {}

enum SomeAssociatedKeys {
    static var name: Void?
}

extension SomeObjectProtocol {
    var name: String {
        get { objc_getAssociatedObject(self, &SomeAssociatedKeys.name) as? String ?? "" }
        set { objc_setAssociatedObject(self, &SomeAssociatedKeys.name, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private final class SomeObject: SomeObjectProtocol {
    init() {}
}

func testSomeObject() {
    testSomeObjectProtocol(obj: SomeObject())
}

func testSomeObjectProtocol(obj: SomeObjectProtocol) {
    obj.name = "yuman"
    print(obj.name)
}
