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
    
    subscript(_ range: CountableRange<Int>) -> Substring? {
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

public extension String {
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
    
    func ranges<T>(of aString: T, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] where T: StringProtocol {
        var ranges: [Range<Index>] = []
        while let range = range(of: aString, options: options, range: (ranges.last?.upperBound ?? startIndex) ..< endIndex, locale: locale) {
            ranges.append(range)
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
    var containsChinese: Bool {
        contains { $0.isChinese }
    }
    
    var containsEmoji: Bool {
        contains { $0.isEmoji }
    }
    
    var capitalizeFirstLetter: String {
        (first?.uppercased() ?? "") + dropFirst()
    }

    var languageDirection: Locale.LanguageDirection {
        // CFStringTokenizerCopyBestStringLanguage documentation says 200-400 characters are required to reliably guess the language
        // Use the lower end(200) for speed
        let cfStr = String(self) as CFString
        let range = CFRange(location: 0, length: Swift.min(200, CFStringGetLength(cfStr)))
        guard let localeId = CFStringTokenizerCopyBestStringLanguage(cfStr, range) else { return .unknown }
        return Locale(identifier: String(localeId)).language.characterDirection
    }
}
