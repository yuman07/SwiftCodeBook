//
//  ActorNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/9.
//

import Foundation

// Actor是可重入的，即调用Actor上的方法时，虽然是顺序执行
// 但是如果某个方法中有await，执行该方法到await时，该方法会放弃当前线程，先hold，让后面的方法先执行
// 在开发中我们有时会遇到一个需求：在actor初始化完毕后，还需要执行一个async的setup方法
// 该actor的所有方法都必须等该setup结束后才能执行
// 可以通过持有该setup的task来实现该需求：
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
    lazy var setupTask: Task<Void, Never> = {
        Task {
            file = await setup()
        }
    }()

    func play() async {
        await setupTask.value
        print("play: \(file ?? 0)")
    }
    
    func pause() async {
        await setupTask.value
        print("pause: \(file ?? 0)")
    }
}

private func setup() async -> Int {
    print("setup begin")
    try? await Task.sleep(for: .seconds(2))
    print("setup end")
    return 100
}

// globalActor
@globalActor actor MyActor {
    static let shared = MyActor()
}
