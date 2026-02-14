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
        let nsString = attributedString.string as NSString
        
        while true {
            let range = nsString.rangeOfCharacter(from: characterSet)
            guard range.location == 0 && range.length > 0 && nsString.isValidRange(range) else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        while true {
            let range = nsString.rangeOfCharacter(from: characterSet, options: .backwards)
            guard range.endLocation == nsString.length && range.length > 0 && nsString.isValidRange(range) else { break }
            attributedString.deleteCharacters(in: range)
        }
        
        return NSAttributedString(attributedString: attributedString)
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
            location = range.endLocation
        }
        if location < length || !omittingEmptySubsequences {
            components.append(attributedSubstring(from: NSRange(location: location, length: length - location)))
        }

        return components
    }
}
