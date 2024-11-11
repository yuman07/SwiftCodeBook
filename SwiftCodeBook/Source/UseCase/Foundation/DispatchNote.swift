//
//  DispatchNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/10/31.
//

import Foundation

final class TestDispatchNote {
    // DispatchSemaphore: 信号量
    // 有一个初始值(Int)，调用signal会将该值+1，调用wait会先将该值-1然后判断：如果小于0则同步等待直到值>=0或者超时
    // 注意点：
    // 1) 初始值必须非负
    // 2) 当初始值大于0时，必须保证该DispatchSemaphore最终释放时的值不小于创建时的初始值
    // 3) 使用DispatchSemaphore很容易造成优先级翻转，具体请参阅：https://developer.apple.com/documentation/xcode/diagnosing-performance-issues-early
    // 由于以上限制，强烈建议尽量不使用DispatchSemaphore，如果要使用也要以0作为其初始值
    // 要避免优先级翻转需要让semaphore.wait的线程的QoS小于或等于semaphore.signal的线程的QoS
    func testSemaphore() {
        // 可以使用DispatchSemaphore来做线程同步
        // 比如你需要阻塞以等待另一个异步操作
        let semaphore = DispatchSemaphore(value: 0)
        print("begin async")
        DispatchQueue.global(qos: .init(rawValue: qos_class_self()) ?? .default).asyncAfter(deadline: .now() + 1.0) {
            print("end async")
            semaphore.signal()
        }
        let result = semaphore.wait(timeout: .now() + 3.0)
        switch result {
        case .success:
            print("success")
        case .timedOut:
            print("timedOut")
        }
    }
    
    func testGetQos() {
        print("main QoS: \(qos_class_main())")
        print("current QoS: \(qos_class_self())")
    }
}
