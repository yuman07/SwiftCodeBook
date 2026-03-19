//
//  NSAttributedString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/6/29.
//

import Foundation

public extension NSAttributedString {
    var fullRange: NSRange {
        NSRange(location: 0, length: length)
    }

    func trimmingCharacters(in characterSet: CharacterSet) -> NSAttributedString {
        let nsString = string as NSString
        let invertedSet = characterSet.inverted
        
        let leadingRange = nsString.rangeOfCharacter(from: invertedSet)
        guard nsString.isValidRange(leadingRange), leadingRange.length > 0 else {
            return NSAttributedString()
        }
        
        let trailingRange = nsString.rangeOfCharacter(from: invertedSet, options: .backwards)
        guard nsString.isValidRange(trailingRange), trailingRange.length > 0 else {
            return NSAttributedString()
        }
        
        let range = NSRange(location: leadingRange.location, length: trailingRange.upperBound - leadingRange.location)
        return range == fullRange ? self : attributedSubstring(from: range)
    }

    func split(
        separator: String,
        options: NSString.CompareOptions = [],
        locale: Locale? = nil,
        keepSeparator: Bool = false,
        omittingEmptySubsequences: Bool = true
    ) -> [NSAttributedString] {
        let ranges = (string as NSString).ranges(of: separator, options: options, locale: locale)
        var components = [NSAttributedString]()
        var location = 0

        for range in ranges {
            if location < range.location || !omittingEmptySubsequences {
                components.append(attributedSubstring(from: NSRange(location: location, length: range.location - location)))
            }
            if keepSeparator {
                components.append(attributedSubstring(from: range))
            }
            location = range.upperBound
        }
        if location < length || !omittingEmptySubsequences {
            components.append(attributedSubstring(from: NSRange(location: location, length: length - location)))
        }

        return components
    }
}
