//
//  DispatchSemaphoreAndGroup.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/10/31.
//

import Foundation

final class DispatchSemaphoreAndGroup {
    // DispatchSemaphore: 信号量
    // https://developer.apple.com/documentation/dispatch/1452955-dispatch_semaphore_create
    // 有一个初始值(Int)，调用signal会将该值+1，调用wait会先将该值-1然后判断：如果小于0则同步等待直到值>=0或者超时
    // 注意点：
    // 1) 初始值必须非负
    // 2) signal/wait尽量保持平衡，必须保证该DispatchSemaphore最终释放时的值不小于创建时的初始值
    func ss() {
        let a = DispatchSemaphore(value: 0)
//        a.signal()
//        a.wait()
        a.signal()
        print(a.wait(timeout: .now() + 2.0))
        print(a.wait(timeout: .now() + 2.0))
        print("123")
    }
}
