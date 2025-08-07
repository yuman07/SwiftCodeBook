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
        keepMatches: Bool = false
    ) -> [AttributedSubstring] where T: StringProtocol {
        guard case let ranges = ranges(of: separator, options: options, locale: locale), !ranges.isEmpty else { return [self[startIndex ..< endIndex]] }

        var components = [AttributedSubstring]()
        for idx in 0 ..< ranges.count {
            let range = ranges[idx]
            if idx == 0 {
                components.append(self[startIndex ..< range.lowerBound])
            }
            if keepMatches {
                components.append(self[range])
            }
            if idx == ranges.count - 1 {
                components.append(self[range.upperBound ..< endIndex])
            }
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
