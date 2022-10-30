//
//  Task+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/30.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * seconds))
    }
}
