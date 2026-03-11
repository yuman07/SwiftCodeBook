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
        var ranges = [NSRange]()
        var location = 0
        while location < length,
              case let range = range(of: searchString, options: options, range: NSRange(location: location, length: length - location), locale: locale),
              isValidRange(range) {
            ranges.append(range)
            location = range.upperBound
        }
        return ranges
    }
}
