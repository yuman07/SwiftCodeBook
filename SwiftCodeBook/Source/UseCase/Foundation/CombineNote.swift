//
//  CombineNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/8.
//

import Combine
import Foundation

// 在开发中我们有时需要一种的效果：
// 当用户产生一个操作，我们先不着急触发真正的Action，而是启动一个计时器
// 如果在规定的时间内又有该操作，则重置计时器重新计时，直至满足规定时间内没有新的操作再去执行Action
// 这个效果可以使用Debounce来完成

// 这里用Debounce实现效果：当用户在规定时间内没有输入，则再进行搜索
private final class TestDebounce01 {
    let inputSubject = CurrentValueSubject<String, Never>("")
    var cancellable: AnyCancellable?
    
    init() {
        cancellable = inputSubject
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] input in
                guard let self else { return }
                search(input: input)
            }
    }
    
    func update(input: String) {
        inputSubject.send(input)
    }
    
    func search(input: String) {
        print("search: \(input)")
    }
}

// 这里用Debounce实现效果：当map在规定时间内没有新操作时，就进行清理以节省内存
private final class TestDebounce02 {
    var map = [String: String]()
    let eventSubject = PassthroughSubject<Void, Never>()
    var cancellable: AnyCancellable?
    
    init() {
        cancellable = eventSubject
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                map.removeAll()
            }
    }
    
    func get(key: String) -> String? {
        eventSubject.send()
        return map[key]
    }
    
    func set(value: String, key: String) {
        eventSubject.send()
        map[key] = value
    }
}
