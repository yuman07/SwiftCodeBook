//
//  BinaryFloatingPoint+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/4/5.
//

import Foundation

public extension BinaryFloatingPoint {
    func equals(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        if self == other { return true }
        if isNaN || other.isNaN { return false }
        if isInfinite || other.isInfinite { return self == other }
        return abs(self - other) <= abs(tolerance)
    }
    
    func greaterThan(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self > other && !equals(other, tolerance: tolerance)
    }
    
    func lessThan(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self < other && !equals(other, tolerance: tolerance)
    }
    
    func greaterThanOrEquals(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self > other || equals(other, tolerance: tolerance)
    }
    
    func lessThanOrEquals(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self < other || equals(other, tolerance: tolerance)
    }
}
