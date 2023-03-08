//
//  CGFloat+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/8.
//

import Foundation

public extension CGFloat {
    static func degreeFrom(radian: CGFloat) -> CGFloat {
        radian * 180 / .pi
    }
    
    static func radianFrom(degree: CGFloat) -> CGFloat {
        degree * .pi / 180
    }
}
