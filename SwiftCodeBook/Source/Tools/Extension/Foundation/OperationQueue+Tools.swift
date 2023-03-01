//
//  OperationQueue+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/1.
//

import Foundation

public extension OperationQueue {
    convenience init(maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount) {
        self.init()
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
    }
}
