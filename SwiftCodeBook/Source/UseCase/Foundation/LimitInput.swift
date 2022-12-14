//
//  LimitInput.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import Foundation

final class LimitInput {
    var doubleValue = 0.0 {
        didSet {
            doubleValue = max(0, min(1, doubleValue))
        }
    }
}
