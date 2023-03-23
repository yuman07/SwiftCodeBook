//
//  KVO.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/4.
//

import Combine
import Foundation

class KVOTest {
    let item = KVOItem()
    var cancelBag = Set<AnyCancellable>()
    
    init() {
        item.publisher(for: \.age)
            .sink { age in
                print(age)
            }.store(in: &cancelBag)
        
        item.publisher(for: \.name)
            .sink { name in
                print(name)
            }.store(in: &cancelBag)
        
        item.age = 1
        item.age = 2
        item.name = "name1"
        item.name = "name2"
    }
}

// must inherit from NSObject
class KVOItem: NSObject {
    // must add '@objc dynamic'
    @objc dynamic var age: Int = 0
}

extension KVOItem {
    private enum AssociatedKeys {
        static var name = "name"
    }
    
    // works the same for associative properties, also add '@objc dynamic'
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
