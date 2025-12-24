//
//  Duration+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/12/24.
//

import Foundation

public extension Duration {
    var seconds: TimeInterval {
        TimeInterval((self / .seconds(1)))
    }

    var milliseconds: TimeInterval {
        TimeInterval((self / .milliseconds(1)))
    }
}
