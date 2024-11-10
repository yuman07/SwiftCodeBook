//
//  ActorNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/9.
//

import Foundation

// Actor是可重入的，即调用Actor上的方法时，虽然是顺序执行
// 但是如果某个方法中有await，执行该方法到await时，该方法会放弃当前线程，先hold，让后面的方法先执行
// 截止目前Actor还不支持关闭该特性，虽然大部分情况可重入也没有问题，但也有一些场景我们需要它不可重入
// 以下进行讨论并给出可能的解决方法

// 需要不可重入的一个例子是某个Actor的初始化还需要调用一个async setup
// 该Actor的所有方法都必须等这个setup执行完毕后才能执行
final class TestActorNote {
    func testSetupActor() {
        let test = TestSetupActor()
        Task {
            await test.play()
        }
    }
}

private actor TestSetupActor {
    var file: Int?
    
    init() {
        // 使用最高优先级确保setup()是该actor执行的第一个方法
        Task(priority: .high) {
            await setup()
        }
    }
    
    // 利用semaphore和Task.detached，将异步转同步
    // 注意这样做会有优先级翻转问题，仅作为万不得已的手段
    func setup() {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Int?
        Task.detached(priority: Task.currentPriority) {
            print("setup begin")
            result = await read()
            print("setup end")
            semaphore.signal()
        }
        semaphore.wait()
        file = result
    }
    
    func play() {
        print("play: \(file ?? 0)")
    }
}

private func read() async -> Int {
    print("read begin")
    try? await Task.sleep(for: .seconds(2))
    print("read end")
    return 100
}

