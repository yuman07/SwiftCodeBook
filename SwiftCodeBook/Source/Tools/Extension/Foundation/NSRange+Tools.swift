//
//  NSRange+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/28.
//

import Foundation

public extension NSRange {
    var isValid: Bool {
        location >= 0 && location != NSNotFound && length > 0
    }

    var endLocation: Int {
        NSMaxRange(self)
    }
}
