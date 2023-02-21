//
//  UseOptionSet.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/21.
//

import Foundation

private struct Sports: OptionSet {
    let rawValue: Int
    
    static let running = Sports(rawValue: 1 << 0)
    
    static let cycling = Sports(rawValue: 1 << 1)
    
    static let swimming = Sports(rawValue: 1 << 2)
    
    static let fencing = Sports(rawValue: 1 << 3)
    
    static let all: Sports = [.running, .cycling, .swimming, .fencing]
}

func testOptionSet() {
    let ops: Sports = [.running, .cycling]
    print(ops.contains(.cycling))
}
