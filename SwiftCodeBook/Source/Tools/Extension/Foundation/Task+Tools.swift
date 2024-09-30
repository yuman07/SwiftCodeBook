//
//  Task+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/30.
//

import Combine
import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(TimeInterval(NSEC_PER_SEC) * seconds))
    }
}

public extension Task {
    func store(in cancelBag: CancelBag) {
        AnyCancellable({ cancel() }).store(in: cancelBag)
    }
}
