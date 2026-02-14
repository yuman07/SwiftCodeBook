//
//  NSString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/14.
//

import Foundation

public extension NSString {
    func isValidRange(_ nsRange: NSRange) -> Bool {
        nsRange.isValid && nsRange.location < length && nsRange.endLocation <= length
    }

    func nsRange(from range: any RangeExpression<String.Index>) -> NSRange? {
        (self as String).nsRange(from: range)
    }
    
    func ranges(of searchString: String, options: NSString.CompareOptions = [], locale: Locale? = nil) -> [NSRange] {
        var ranges = [NSRange]()
        var location = 0
        while location < length,
              case let range = range(of: searchString, options: options, range: NSRange(location: location, length: length - location), locale: locale),
              isValidRange(range) {
            ranges.append(range)
            location = range.endLocation
        }
        return ranges
    }
}
