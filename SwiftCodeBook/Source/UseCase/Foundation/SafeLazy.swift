//
//  SafeLazy.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation
import os

final class SafeLazy {
    private let logServiceLock = OSAllocatedUnfairLock<NSObject?>(initialState: nil)
    lazy var logService: NSObject = {
        logServiceLock.withLock { service in
            service ?? {
                let newLogService = NSObject()
                service = newLogService
                return newLogService
            }()
        }
    }()
    
    init() {}
}
