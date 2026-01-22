//
//  CGAffineTransform+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/4/20.
//

import Foundation

public extension CGAffineTransform {
    static let verticalAxisSymmetry = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    static let horizontalAxisSymmetry = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
}
