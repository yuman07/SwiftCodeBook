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
        guard !isEmpty && range.lowerBound < count && range.upperBound >= 0 else { return nil }
        let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound))
        let upperIndex = index(startIndex, offsetBy: min(count - 1, range.upperBound))
        return self[lowerIndex...upperIndex]
    }
    
    subscript(_ range: CountableRange<Int>) -> Substring? {
        guard !isEmpty && range.lowerBound < count && range.upperBound > 0 else { return nil }
        let lowerIndex = index(startIndex, offsetBy: max(0, range.lowerBound))
        let upperIndex = index(startIndex, offsetBy: min(count, range.upperBound))
        return self[lowerIndex..<upperIndex]
    }
    
    subscript(_ range: PartialRangeFrom<Int>) -> Substring? {
        guard case let len = count - range.lowerBound, len > 0 else { return nil }
        return suffix(len)
    }
    
    subscript(_ range: PartialRangeUpTo<Int>) -> Substring? {
        guard case let len = range.upperBound - 1, len > 0 else { return nil }
        return prefix(len)
    }
    
    subscript(_ range: PartialRangeThrough<Int>) -> Substring? {
        guard case let len = range.upperBound, len >= 0 else { return nil }
        return prefix(len)
    }
}

public extension String {
    var UTF8Data: Data {
        Data(self.utf8)
    }
}

public extension String {
    var containsChinese: Bool {
        contains { $0.isChinese }
    }
    
    var containsEmoji: Bool {
        contains { $0.isEmoji }
    }
}
