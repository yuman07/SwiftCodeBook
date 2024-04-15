//
//  CGPoint+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/3/8.
//

import Foundation

public extension CGPoint {
    func distanceTo(_ point: CGPoint) -> CGFloat {
        sqrt(pow((point.x - x), 2) + pow((point.y - y), 2))
    }
}
