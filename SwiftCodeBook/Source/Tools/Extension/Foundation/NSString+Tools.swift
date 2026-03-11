//
//  NSString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/14.
//

import Foundation

public extension NSString {
    func isValidRange(_ nsRange: NSRange) -> Bool {
        nsRange.isValid && nsRange.location < length && nsRange.upperBound <= length
    }

    func nsRange<T: RangeExpression<String.Index>>(from range: T) -> NSRange? {
        (self as String).nsRange(from: range)
    }
    
    func ranges(of searchString: String, options: NSString.CompareOptions = [], locale: Locale? = nil) -> [NSRange] {
        guard !searchString.isEmpty else { return [] }
        var ranges = [NSRange]()
        var lastUpperBound = 0
        while lastUpperBound < length,
              case let range = range(of: searchString, options: options, range: NSRange(location: lastUpperBound, length: length - lastUpperBound), locale: locale),
              isValidRange(range) {
            ranges.append(range)
            lastUpperBound = range.upperBound
        }
        return ranges
    }
}
