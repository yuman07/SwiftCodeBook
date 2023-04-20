//
//  AssociatedObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/4.
//

import Foundation

// must be 'class', not 'struct'
final class AssociatedObjectItem {}

extension AssociatedObjectItem {
    private enum AssociatedKeys {
        static var age = "age"
        static var name = "name"
        static var block = "block"
        static var birthDay = "birthDay"
    }
    
    var age: Int {
        get { objc_getAssociatedObject(self, &AssociatedKeys.age) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &AssociatedKeys.age, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var name: String {
        get { objc_getAssociatedObject(self, &AssociatedKeys.name) as? String ?? "" }
        set { objc_setAssociatedObject(self, &AssociatedKeys.name, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var block: (() -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.block) as? () -> Void }
        set { objc_setAssociatedObject(self, &AssociatedKeys.block, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var birthDay: Date {
        objc_getAssociatedObject(self, &AssociatedKeys.birthDay) as? Date ?? {
            let date = Date()
            objc_setAssociatedObject(self, &AssociatedKeys.birthDay, date, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return date
        }()
    }
}
