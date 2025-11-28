//
//  SerialTask.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/11/28.
//

import Foundation

// 当我们使用Task{}来包裹一个任务时，注意这个block可以被理解是放到了一个global queue来执行
// 即如果我们依次创建TaskA/TaskB，但是实际内部block执行顺序是不确定的
// 如果这两个task的创建处于不同线程，那倒还好，因为多线程时本来两者的创建时机也是不稳定的，我们不需要强行保证顺序执行
// 但如果这两个task是在同一个线程依次创建，那我们可能就要看是否业务上要求两者必须严格按顺序执行了
// 一个可能的场景：用户每输入一个字符我们都要发送一个网络请求，网络请求调用是一个await方法，需要放到Task里，且我们必须要保证网络请求是顺序的
// 如果没有特殊处理，因为输入回调都是在主线程，即创建Task都是顺序的，但我们没法保证实际Task的执行顺序(即网络请求顺序)是串行的
// 以下是使用AsyncStream来解决这个问题

final class SerialTaskAndActor {
    private let (stream, continuation) = AsyncStream<String>.makeStream()
    private let networkService = NetworkService()

    init() {
        Task {
            // 这里的for await其实保证了两件事：
            // 1) 事件按顺序从 AsyncStream 取出
            // 2) 每次 await sendRequest 完成后，才会继续下一次循环
            // 因此也能保证actor里的sendRequest的调用顺序和实际执行顺序一致
            // 注意这也保证了networkService.sendRequest不会发生重入，即一定是上一个全部执行完了才会执行下一个
            for await text in stream {
                await networkService.sendRequest(for: text)
            }
        }
    }
    
    deinit {
        continuation.finish()
    }
    
    func userDidInput(_ text: String) {
        // yield 是同步调用，顺序完全跟输入一致
        continuation.yield(text)
    }
}

private actor NetworkService {
    func sendRequest(for text: String) {
        print(text)
    }
}
