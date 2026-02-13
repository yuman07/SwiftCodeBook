//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension String {
    subscript(_ position: Int) -> Character? {
        guard position >= 0, let index = index(startIndex, offsetBy: position, limitedBy: endIndex), index < endIndex else { return nil }
        return self[index]
    }
    
    subscript(_ range: ClosedRange<Int>) -> Substring? {
        guard range.lowerBound >= 0,
              let lowerIndex = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex),
              lowerIndex < endIndex && upperIndex < endIndex
        else { return nil }
        return self[lowerIndex ... upperIndex]
    }
    
    subscript(_ range: Range<Int>) -> Substring? {
        guard range.lowerBound >= 0,
              let lowerIndex = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex),
              lowerIndex < endIndex && upperIndex <= endIndex
        else { return nil }
        return self[lowerIndex ..< upperIndex]
    }
    
    // [0...]
    subscript(_ range: PartialRangeFrom<Int>) -> Substring? {
        guard range.lowerBound >= 0,
              let lowerIndex = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
              lowerIndex < endIndex
        else { return nil }
        return self[lowerIndex...]
    }
    
    // [..<2]
    subscript(_ range: PartialRangeUpTo<Int>) -> Substring? {
        guard range.upperBound > 0,
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex),
              upperIndex <= endIndex
        else { return nil }
        return self[..<upperIndex]
    }
    
    // [...2]
    subscript(_ range: PartialRangeThrough<Int>) -> Substring? {
        guard range.upperBound >= 0,
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex),
              upperIndex < endIndex
        else { return nil }
        return self[...upperIndex]
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
    
    func ranges<T>(of aString: T, options: String.CompareOptions = [], locale: Locale? = nil) -> [Range<String.Index>] where T: StringProtocol {
        var ranges = [Range<String.Index>]()
        var lastUpperBound = startIndex
        while lastUpperBound < endIndex, let range = range(of: aString, options: options, range: lastUpperBound ..< endIndex, locale: locale) {
            ranges.append(range)
            lastUpperBound = range.upperBound
        }
        return ranges
    }
}

public extension String {
    func validatedRange(_ range: Range<Index>) -> Range<Index>? {
        guard let lower = Index(range.lowerBound, within: self),
              let upper = Index(range.upperBound, within: self),
              lower >= startIndex, upper <= endIndex, lower < upper
        else { return nil }
        return lower ..< upper
    }
    
    func validatedRange(_ range: ClosedRange<Index>) -> ClosedRange<Index>? {
        guard let lower = Index(range.lowerBound, within: self),
              let upper = Index(range.upperBound, within: self),
              lower >= startIndex, upper < endIndex, lower <= upper
        else { return nil }
        return lower ... upper
    }
    
    func validatedRange(_ range: PartialRangeFrom<Index>) -> PartialRangeFrom<Index>? {
        guard let lower = Index(range.lowerBound, within: self),
              lower >= startIndex, lower < endIndex
        else { return nil }
        return lower...
    }
    
    func validatedRange(_ range: PartialRangeUpTo<Index>) -> PartialRangeUpTo<Index>? {
        guard let upper = Index(range.upperBound, within: self),
              upper >= startIndex, upper <= endIndex
        else { return nil }
        return ..<upper
    }
    
    func validatedRange(_ range: PartialRangeThrough<Index>) -> PartialRangeThrough<Index>? {
        guard let upper = Index(range.upperBound, within: self),
              upper >= startIndex, upper < endIndex
        else { return nil }
        return ...upper
    }

    func validatedRange(_ range: NSRange) -> Range<Index>? {
        guard range.location >= 0, range.length >= 0, range.location != NSNotFound, range.length != NSNotFound, NSMaxRange(range) <= utf16.count,
              let lower = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex), lower < utf16.endIndex,
              let upper = utf16.index(lower, offsetBy: range.length, limitedBy: utf16.endIndex), upper < utf16.endIndex, lower < upper,
              let from = Index(lower, within: self), from >= startIndex, from < endIndex,
              let end = Index(upper, within: self), end >= startIndex, end <= endIndex, from < end
        else { return nil }
        return from ..< end
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
