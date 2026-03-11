//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension StringProtocol {
    func isValidRange<T: RangeExpression<Index>>(_ rangeExpression: T) -> Bool {
        let range = rangeExpression.relative(to: self)
        return range.lowerBound >= startIndex && range.upperBound <= endIndex
    }

    func isValidRange(_ nsRange: NSRange) -> Bool {
        guard let range = range(from: nsRange), isValidRange(range) else { return false }
        return true
    }

    func range(from nsRange: NSRange) -> Range<Index>? {
        guard nsRange.isValid else { return nil }
        return Range(nsRange, in: self)
    }

    func nsRange<T: RangeExpression<Index>>(from range: T) -> NSRange? {
        guard isValidRange(range), case let nsRange = NSRange(range, in: self), nsRange.isValid else { return nil }
        return nsRange
    }
}

public extension StringProtocol {
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
    var guessedLanguageDirection: Locale.LanguageDirection {
        // CFStringTokenizerCopyBestStringLanguage documentation says 200-400 characters are required to reliably guess the language
        // Use the lower end(200) for speed
        let cfStr = String(prefix(200)) as CFString
        let range = CFRange(location: 0, length: CFStringGetLength(cfStr))
        guard let localeId = CFStringTokenizerCopyBestStringLanguage(cfStr, range) else { return .unknown }
        return Locale(identifier: String(localeId)).language.characterDirection
    }
}
