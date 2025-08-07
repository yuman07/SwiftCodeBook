//
//  AttributedString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/27.
//

import Foundation

public extension AttributedStringProtocol {
    var text: String {
        String(characters[...])
    }
    
    func ranges<T>(of stringToFind: T, options: String.CompareOptions = [], locale: Locale? = nil) -> [Range<AttributedString.Index>] where T: StringProtocol {
        var ranges = [Range<AttributedString.Index>]()
        var currentStartIndex = startIndex
        while currentStartIndex < endIndex, let range = self[currentStartIndex ..< endIndex].range(of: stringToFind, options: options, locale: locale) {
            ranges.append(range)
            currentStartIndex = range.upperBound
        }
        return ranges
    }

    func split<T>(
        separator: T,
        options: String.CompareOptions = [],
        locale: Locale? = nil,
        keepSeparator: Bool = false,
        omittingEmptySubsequences: Bool = true
    ) -> [AttributedSubstring] where T: StringProtocol {
        let ranges = ranges(of: separator, options: options, locale: locale)
        var components = [AttributedSubstring]()
        var lastUpperBound = startIndex

        for range in ranges {
            if lastUpperBound < range.lowerBound || !omittingEmptySubsequences {
                components.append(self[lastUpperBound ..< range.lowerBound])
            }
            if keepSeparator {
                components.append(self[range])
            }
            lastUpperBound = range.upperBound
        }
        if lastUpperBound < endIndex || !omittingEmptySubsequences {
            components.append(self[lastUpperBound ..< endIndex])
        }

        return components
    }
}

public extension AttributedString {
    func trimmingWhitespacesAndNewlines() -> Self {
        var attributedString = self
        if let range = range(of: #"\s+$"#, options: .regularExpression), !range.isEmpty {
            attributedString.removeSubrange(range)
        }
        if let range = range(of: #"^\s+"#, options: .regularExpression), !range.isEmpty {
            attributedString.removeSubrange(range)
        }
        return attributedString
    }
}
