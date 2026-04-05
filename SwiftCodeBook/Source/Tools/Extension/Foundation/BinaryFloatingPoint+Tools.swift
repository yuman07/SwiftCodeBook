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
        guard isFinite && other.isFinite else { return false }
        return abs(self - other) <= abs(tolerance)
    }
    
    func greaterThanOrEquals(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self > other || equals(other, tolerance: tolerance)
    }
    
    func lessThanOrEquals(_ other: Self, tolerance: Self = Self.ulpOfOne.squareRoot()) -> Bool {
        self < other || equals(other, tolerance: tolerance)
    }
}
