//
//  SafeLazy.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation
import os

// Swift的lazy虽然提供了延迟初始化功能，但有两个缺点：
// 1) 不是线程安全的，即如果多个线程同时访问会有问题
// 2) 必须以var修饰，即lazy var这种。造成了是该value是可读写的，但有时我们仅想让该值只读
// 其实可以不使用lazy，而是计算属性来解决以上需求且也是延迟初始化的
final class SafeLazy {
    // 线程安全 + 只读
    private let readOnlyObjLock = OSAllocatedUnfairLock<NSObject?>(initialState: nil)
    var readOnlyObj: NSObject {
        readOnlyObjLock.withLock { obj in
            obj ?? {
                let newObj = NSObject()
                obj = newObj
                return newObj
            }()
        }
    }
    
    // 线程安全 + 读写(这里假设无所谓操作的时间顺序，因此可以用Lock)
    private let readWriteObjLock = OSAllocatedUnfairLock<NSObject?>(initialState: nil)
    var readWriteObj: NSObject {
        set {
            readWriteObjLock.withLock { $0 = newValue }
        }
        get {
            readWriteObjLock.withLock { obj in
                obj ?? {
                    let newObj = NSObject()
                    obj = newObj
                    return newObj
                }()
            }
        }
    }
    
    init() {}
}
