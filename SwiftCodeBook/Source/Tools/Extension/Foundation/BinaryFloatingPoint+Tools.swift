//
//  BinaryFloatingPoint+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/9.
//

import Foundation

public extension BinaryFloatingPoint {
    /// Returns this value rounded to an integral value.
    ///
    ///     123.12312421.rounded(toPlaces: 3) // 123.123
    ///     Double.pi.rounded(toPlaces: 2) // 3.14
    ///
    /// - Parameter places: The number of decimal places to round to.
    /// - Returns: The rounded value.
    func rounded(toPlaces places: Int) -> Self {
        // https://codereview.stackexchange.com/questions/142748/swift-floatingpoint-rounded-to-places
        guard places >= 0 else { return self }
        let divisor = Self((0..<places).reduce(1.0) { (result, _) in result * 10.0 })
        return (self * divisor).rounded() / divisor
    }
}
