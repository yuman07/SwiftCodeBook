//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension String {
    func isValidRange(_ rangeExpression: any RangeExpression<Index>) -> Bool {
        if let range = rangeExpression as? Range<Index> {
            return range.lowerBound >= startIndex && range.upperBound <= endIndex
        } else if let range = rangeExpression as? ClosedRange<Index> {
            return range.lowerBound >= startIndex && range.upperBound < endIndex
        } else if let range = rangeExpression as? PartialRangeFrom<Index> {
            return range.lowerBound >= startIndex
        } else if let range = rangeExpression as? PartialRangeUpTo<Index> {
            return range.upperBound <= endIndex
        } else if let range = rangeExpression as? PartialRangeThrough<Index> {
            return range.upperBound < endIndex
        }
        return false
    }

    func isValidRange(_ nsRange: NSRange) -> Bool {
        range(from: nsRange) != nil
    }

    func range(from nsRange: NSRange) -> Range<Index>? {
        guard nsRange.isValid else { return nil }
        return Range(nsRange, in: self)
    }

    func nsRange(from range: any RangeExpression<Index>) -> NSRange? {
        guard isValidRange(range) else { return nil }
        return NSRange(range, in: self)
    }
}

public extension StringProtocol {
    // 对给定的index进行移动，正数向后，负数向前，最终结果在[startIndex, endIndex)即有效
    func indexSafely(_ i: Index, offsetBy distance: Int) -> Index? {
        var currentIndex = i
        var count = abs(distance)
        
        while count > 0 {
            if distance > 0 {
                guard currentIndex < endIndex else { return nil }
                currentIndex = index(after: currentIndex)
            } else {
                guard currentIndex > startIndex else { return nil }
                currentIndex = index(before: currentIndex)
            }
            count -= 1
        }
        
        guard currentIndex >= startIndex && currentIndex < endIndex else { return nil }
        return currentIndex
    }
    
    func forEachWithIndexAndChar(_ body: (Index, Character) throws -> Void) rethrows {
        var currentIndex = startIndex
        while currentIndex < endIndex {
            try body(currentIndex, self[currentIndex])
            currentIndex = index(after: currentIndex)
        }
    }
    
    func ranges<T>(of aString: T, options: String.CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] where T: StringProtocol {
        var ranges = [Range<Index>]()
        var lastUpperBound = startIndex
        while lastUpperBound < endIndex, let range = range(of: aString, options: options, range: lastUpperBound ..< endIndex, locale: locale) {
            ranges.append(range)
            lastUpperBound = range.upperBound
        }
        return ranges
    }
}

public extension StringProtocol {
    var utf8Data: Data {
        Data(utf8)
    }
}

public extension StringProtocol {
    var languageDirection: Locale.LanguageDirection {
        // CFStringTokenizerCopyBestStringLanguage documentation says 200-400 characters are required to reliably guess the language
        // Use the lower end(200) for speed
        let cfStr = String(self) as CFString
        let range = CFRange(location: 0, length: Swift.min(200, CFStringGetLength(cfStr)))
        guard let localeId = CFStringTokenizerCopyBestStringLanguage(cfStr, range) else { return .unknown }
        return Locale(identifier: String(localeId)).language.characterDirection
    }
}
