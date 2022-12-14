//
//  CGAffineTransformGuide.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import Foundation

func CGAffineTransformGuide() {
    // zero Transform
    var transform = CGAffineTransform.identity
    print(transform)
    
    // Translation transformation(coordinate system and direction are the same as UIKit)
    transform = CGAffineTransform(translationX: 1, y: 2)
    
    // Scaling transformation (x and y are scaling ratios, both are non-negative)
    transform = CGAffineTransform(scaleX: 0.1, y: 2)
    
    // Rotation transformation
    // (the value passed in is radians, .pi is 180°)
    // (positive numbers are clockwise, negative numbers are counterclockwise)
    transform = CGAffineTransform(rotationAngle: .pi)
    
    // Symmetric transformation (symmetrical along the X axis)
    transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    
    // Symmetric transformation (symmetrical along the Y axis)
    transform = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    
    // Symmetric transformation (symmetry about the origin)
    transform = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    
    // Symmetric transformation (symmetric along y=x)
    transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
}

// Combination transformation (I want to achieve an effect of "scaling first, then rotating, and finally symmetry")
// There are two implementations here
func CombinationTransformation() {
    /// Implementation method 1
    /// Note that when connecting different transformations in this way, the order of effects and the order of codes are reversed
    var transform1 = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    transform1 = transform1.rotated(by: .pi / 2)
    transform1 = transform1.scaledBy(x: 0.5, y: 0.5)
    
    /// Implementation method 2
    // Note that when using concatenating to connect different transformations, the effect order is the same as the code order
    let t1 = CGAffineTransform(scaleX: 0.5, y: 0.5)
    let t2 = CGAffineTransform(rotationAngle: .pi / 2)
    let t3 = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0)
    
    var transform2 = t1.concatenating(t2)
    transform2 = transform2.concatenating(t3)
}
