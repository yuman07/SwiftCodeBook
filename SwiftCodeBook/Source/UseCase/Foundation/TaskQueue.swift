//
//  TaskQueue.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/9/30.
//

import Foundation

// 当我们使用Task{...}时，Task会继承当前上下文的Actor
// 比如当我们在UIView/VC等组件中使用Task{...}，等价于Task{ @MainActor in ... }
// 即此时该Task内的block均运行于主线程(当然因为是主线程肯定也是串行的)

// 如果当前上下文没有Actor信息，比如就在一个普通的class中使用Task{...}
// 那该Task的block会运行在一个并发队列(其实在老的iOS版本中是一个串行线程，但我们不应该去假定其背后的实现，即我们不能保证该Queue一定是串行的)
// 那这样会造成可能的多线程问题，比如我们需要流式计算一个网络响应数据的hash值，尽管回调是串行的，但由于Task的block是并行的，因此可能先计算后面的data再计算前面的
// 即有些时候我们确实需要一个Task内的block是串行执行

func testTask() {
    let test = Test()
    test.test1()
    // test.test2()
}

@globalActor actor MyActor {
    static let shared = MyActor()
}

private final class Test {
    func test1() {
        let tmp = SomeActor()
        for idx in 1 ... 10000 {
            print("out: \(idx)")
            // 如上所述，因为Test就是一个普通的class，Task会运行于一个并发队列
            // 即造成in/SomeActor的输出是错乱的
            Task {
                print("in: \(idx)")
                await tmp.ppp(index: idx)
            }
        }
    }
    
    func test2() {
        let tmp = SomeActor()
        for idx in 1 ... 10000 {
            print("out: \(idx)")
            // 使用 @MyActor 修饰后，in/SomeActor的输出是顺序的
            Task { @MyActor in
                print("in: \(idx)")
                await tmp.ppp(index: idx)
            }
        }
    }
}

private final actor SomeActor {
    func ppp(index: Int) {
        print("SomeActor: \(index)")
    }
}
