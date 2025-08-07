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
        guard case let ranges = string.ranges(of: separator, options: options, locale: locale), !ranges.isEmpty else { return [self] }

        var components = [NSAttributedString]()
        for idx in 0 ..< ranges.count {
            let range = ranges[idx]
            if idx == 0 {
                components.append(attributedSubstring(from: NSRange(string.startIndex ..< range.lowerBound, in: string)))
            }
            if keepMatches {
                components.append(attributedSubstring(from: NSRange(range, in: string)))
            }
            if idx == ranges.count - 1 {
                components.append(attributedSubstring(from: NSRange(range.upperBound ..< string.endIndex, in: string)))
            }
        }

        return components
    }
}
