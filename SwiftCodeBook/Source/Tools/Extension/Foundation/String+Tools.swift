//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension String {
    /// Safely subscript Character with index.
    ///
    ///     let value = "Abcdef123456"
    ///     value[3] // "d"
    ///     value[99] // nil
    ///
    /// - Parameter i: index.
    subscript(_ position: Int) -> Character? {
        guard 0..<count ~= position else { return nil }
        return self[index(startIndex, offsetBy: position)]
    }

    /// Safely subscript string within a closed range.
    ///
    ///     let value = "Abcdef123456"
    ///     value[3...6] // "def1"
    ///     value[3...99] // "def123456"
    ///     value[99...199] // nil
    ///
    /// - Parameter range: Closed range.
    subscript(_ range: ClosedRange<Int>) -> Substring? {
        guard let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound), limitedBy: endIndex),
              let upperIndex = index(lowerIndex, offsetBy: range.upperBound - range.lowerBound + 1, limitedBy: endIndex)
        else {
            guard range.lowerBound < count else { return nil }
            return dropFirst(range.lowerBound)
        }
        return self[lowerIndex..<upperIndex]
    }

    /// Safely subscript string within a half-open range.
    ///
    ///     let value = "Abcdef123456"
    ///     value[3..<6] // "def"
    ///     value[3..<99] // "def123456"
    ///     value[99..<199] // nil
    ///
    /// - Parameter range: Half-open range.
    subscript(_ range: CountableRange<Int>) -> Substring? {
        guard let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound), limitedBy: endIndex),
              let upperIndex = index(lowerIndex, offsetBy: range.upperBound - range.lowerBound, limitedBy: endIndex)
        else {
            guard range.lowerBound < count else { return nil }
            return dropFirst(range.lowerBound)
        }
        return self[lowerIndex..<upperIndex]
    }
}

public extension String {
    func allIndicesOf(string: String) -> [Int] {
        var indices = [Int]()
        var start = startIndex
        while start < endIndex, let range = range(of: string, range: start..<endIndex), !range.isEmpty {
            indices.append(distance(from: startIndex, to: range.lowerBound))
            start = range.upperBound
        }
        return indices
    }
}

public extension String {
    var containsChinese: Bool {
        contains { $0.isChinese }
    }
    
    var containsEmoji: Bool {
        contains { $0.isEmoji }
    }
}
