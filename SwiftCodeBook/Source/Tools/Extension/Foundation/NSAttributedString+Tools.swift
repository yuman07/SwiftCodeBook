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
        let attributedString = NSMutableAttributedString(attributedString: self)
        var range = NSRange()
        
        while true {
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet)
            guard range.location == 0 && range.length > 0 else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        while true {
            range = (attributedString.string as NSString).rangeOfCharacter(from: characterSet, options: .backwards)
            guard NSMaxRange(range) == attributedString.length && range.length > 0 else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        return NSAttributedString(attributedString: attributedString)
    }

    func split<T>(
        separator: T,
        options: String.CompareOptions = [],
        locale: Locale? = nil,
        keepMatches: Bool = false
    ) -> [NSAttributedString] where T: StringProtocol {
        let ranges = string.ranges(of: separator, options: options, locale: locale)
        var components = [NSAttributedString]()
        var lastUpperBound = string.startIndex

        for range in ranges {
            components.append(attributedSubstring(from: NSRange(lastUpperBound ..< range.lowerBound, in: string)))
            if keepMatches {
                components.append(attributedSubstring(from: NSRange(range, in: string)))
            }
            lastUpperBound = range.upperBound
        }
        components.append(attributedSubstring(from: NSRange(lastUpperBound ..< string.endIndex, in: string)))

        return components
    }
}
