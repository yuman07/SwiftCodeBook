//
//  KVO.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/4.
//

import Foundation

class KVOTest {
    let item = KVOItem()
    var ageToken: NSKeyValueObservation?
    var nameToken: NSKeyValueObservation?
    
    init() {
        ageToken = item.observe(\.age, options: [.initial, .old, .new], changeHandler: { obj, change in
            print(change.oldValue ?? "NilAge")
            print(change.newValue ?? "NilAge")
            print("---age---")
        })
        
        nameToken = item.observe(\.name, options: [.initial, .old, .new], changeHandler: { obj, change in
            print(change.oldValue ?? "NilName")
            print(change.newValue ?? "NilName")
            print("---name---")
        })
        
        item.age = 1
        item.age = 2
        item.age = 3
        item.name = "11"
        item.name = "22"
        item.name = "33"
    }
    
    deinit {
        ageToken?.invalidate()
        nameToken?.invalidate()
    }
}

// Must inherit from NSObject
class KVOItem: NSObject {
    // must add '@objc dynamic'
    @objc dynamic var age: Int = 0
}

extension KVOItem {
    private struct AssociatedKeys {
        static var name = "name"
    }
    
    // Works the same for associative properties, also add '@objc dynamic'
    @objc dynamic
    var name: String {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.name) as? String) ?? ""
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.name, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
