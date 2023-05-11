//
//  AsyncToSync.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/5/11.
//

import Foundation

func testAsyncToSync() {
    print("testAsyncToSync_start")
    print("testAsyncToSync_\(syncMethod())")
    print("testAsyncToSync_end")
}

private func asyncMethod(callback: @escaping (String) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
        callback(UUID().uuidString)
    }
}

private func syncMethod() -> String {
    var result = ""
    let group = DispatchGroup()
    group.enter()
    asyncMethod {
        result = $0
        group.leave()
    }
    group.wait()
    return result
}
