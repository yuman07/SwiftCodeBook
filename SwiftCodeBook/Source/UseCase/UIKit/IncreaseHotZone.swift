//
//  IncreaseHotZone.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/19.
//

import UIKit

// if need increase hot zone, pass negative number, otherwise, pass positive number
// The meaning of the example is: the hot zone increased by 10 on the top and right, and the hot zone decreased by 10 on the left and bottom
class IncreaseHotZoneView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let edge = UIEdgeInsets(top: -10, left: 10, bottom: 10, right: -10)
        return bounds.inset(by: edge).contains(point)
    }
}
