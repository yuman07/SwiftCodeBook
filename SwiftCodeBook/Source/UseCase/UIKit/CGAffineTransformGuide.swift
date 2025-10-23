//
//  CGAffineTransformGuide.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import CoreGraphics
import Foundation

// Combination transformation (I want to achieve an effect of "scaling first, then rotating, and finally symmetry")
// There are two implementations here
func CombinationTransformation() {
    /// Implementation method 1
    /// Note that when connecting different transformations in this way, the order of effects and the order of codes are reversed
    var transform1 = CGAffineTransform.horizontalAxisSymmetry
    transform1 = transform1.rotated(by: .pi / 2)
    transform1 = transform1.scaledBy(x: 0.5, y: 0.5)
    
    /// Implementation method 2
    // Note that when using concatenating to connect different transformations, the effect order is the same as the code order
    let transform2 = CGAffineTransform(scaleX: 0.5, y: 0.5)
        .concatenating(CGAffineTransform(rotationAngle: .pi / 2))
        .concatenating(.horizontalAxisSymmetry)
    print(transform2)
}
