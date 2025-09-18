//
//  CGSize+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/2/27.
//

import Foundation

public extension CGSize {
    static var one: Self {
        CGSize(width: 1, height: 1)
    }

    var isValid: Bool {
        width.isFinite && width > 0 && height.isFinite && height > 0
    }

    var validSelfOrOne: Self {
        isValid ? self : .one
    }
}
