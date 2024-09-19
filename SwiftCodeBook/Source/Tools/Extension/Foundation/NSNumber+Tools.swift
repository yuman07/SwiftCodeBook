//
//  NSNumber+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/4/18.
//

import UIKit

public extension NSNumber {
    var cgFloatValue: CGFloat {
        CGFloat(doubleValue)
    }
}
