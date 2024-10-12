//
//  OSAllocatedUnfairLock+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/10/12.
//

import Foundation
import os

public extension OSAllocatedUnfairLock {
    var value: State {
        withLock { $0 }
    }
}
