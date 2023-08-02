//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension String {
    subscript(_ position: Int) -> Character? {
        guard 0 ..< count ~= position else { return nil }
        return self[index(startIndex, offsetBy: position)]
    }
    
    subscript(_ range: ClosedRange<Int>) -> Substring? {
        guard !isEmpty && range.lowerBound >= 0 && range.upperBound < count,
              let lowerIndex = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex)
        else { return nil }
        return self[lowerIndex ... upperIndex]
    }
    
    subscript(_ range: CountableRange<Int>) -> Substring? {
        guard !isEmpty && range.lowerBound >= 0 && range.upperBound <= count,
              let lowerIndex = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
              let upperIndex = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex)
        else { return nil }
        return self[lowerIndex ..< upperIndex]
    }
    
    // [0...]
    subscript(_ range: PartialRangeFrom<Int>) -> Substring? {
        guard case let len = count - range.lowerBound, len > 0, range.lowerBound >= 0 else { return nil }
        return suffix(len)
    }
    
    // [..<2]
    subscript(_ range: PartialRangeUpTo<Int>) -> Substring? {
        guard case let len = range.upperBound - 1, len > 0 else { return nil }
        return prefix(len)
    }
    
    // [...2]
    subscript(_ range: PartialRangeThrough<Int>) -> Substring? {
        guard case let len = range.upperBound, len >= 0 else { return nil }
        return prefix(len)
    }
}

public extension String {
    func indexSafely(after idx: Index) -> Index? {
        guard idx < endIndex else { return nil }
        return index(after: idx)
    }
    
    func indexSafely(before idx: Index) -> Index? {
        guard idx > startIndex else { return nil }
        return self.index(before: idx)
    }
    
    func firstIndex(of char: Character, after idx: Index) -> Index? {
        indexSafely(after: idx).flatMap { self[$0 ..< endIndex].firstIndex(of: char) }
    }
    
    func lastIndex(of char: Character, before idx: Index) -> Index? {
        indexSafely(before: idx).flatMap { self[startIndex ... $0].lastIndex(of: char) }
    }
    
    func forEachWithIndex(_ body: (Index, Character) throws -> Void) rethrows {
        var curIndex = startIndex
        for char in self {
            try body(curIndex, char)
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
    
    var capitalizeTheFirstLetter: String {
        (first?.uppercased() ?? "") + dropFirst()
    }
}
