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
}
