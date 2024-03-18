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
    func indexSafely(after idx: Self.Index) -> Self.Index? {
        guard idx < endIndex else { return nil }
        return index(after: idx)
    }
    
    func indexSafely(before idx: Self.Index) -> Self.Index? {
        guard idx > startIndex else { return nil }
        return self.index(before: idx)
    }
    
    func firstIndex(of char: Character, after idx: Self.Index) -> Self.Index? {
        indexSafely(after: idx).flatMap { self[$0 ..< endIndex].firstIndex(of: char) }
    }
    
    func lastIndex(of char: Character, before idx: Self.Index) -> Self.Index? {
        indexSafely(before: idx).flatMap { self[startIndex ... $0].lastIndex(of: char) }
    }
    
    func forEachWithIndex(_ body: (Self.Index, Character) throws -> Void) rethrows {
        var curIndex = startIndex
        while curIndex < endIndex {
            try body(curIndex, self[curIndex])
            curIndex = index(after: curIndex)
        }
    }
    
    func allClosedRangeOfPaired(startChar: Character, endChar: Character) -> [ClosedRange<Index>] {
        var stack = [Index]()
        var ranges = [ClosedRange<Index>]()
        
        forEachWithIndex { index, char in
            if char == startChar {
                stack.append(index)
            } else if char == endChar, let start = stack.last {
                stack.removeLast()
                ranges.append(start ... index)
            }
        }
        
        return ranges
    }

    func ranges<T>(of aString: T, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Self.Index>] where T : StringProtocol {
      var ranges: [Range<Self.Index>] = []
      while let range = range(of: aString, options: options, range: (ranges.last?.upperBound ?? self.startIndex) ..< self.endIndex, locale: locale) {
        ranges.append(range)
      }
      return ranges
    }
}

public extension String {
    var UTF8Data: Data {
        Data(utf8)
    }
}

public extension String {
    var containsChinese: Bool {
        contains { $0.isChinese }
    }
    
    var containsEmoji: Bool {
        contains { $0.isEmoji }
    }
    
    var capitalizeTheFirstLetter: Self {
        (first?.uppercased() ?? "") + dropFirst()
    }
    
    var stripAllHTMLTags: Self {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
