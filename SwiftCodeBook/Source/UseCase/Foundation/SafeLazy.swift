//
//  SafeLazy.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation

final class SafeLazy {
    private let logServiceLock = NSLock()
    private var privateLogService: NSObject?
    lazy var logService: NSObject = {
        logServiceLock.withLock {
            if let privateLogService {
                return privateLogService
            } else {
                let newLogService = NSObject()
                privateLogService = newLogService
                return newLogService
            }
        }
    }()
    
    init() {}
}
