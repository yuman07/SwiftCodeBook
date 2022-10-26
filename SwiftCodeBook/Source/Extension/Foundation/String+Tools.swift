//
//  String+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension String {
    func allIndicesOf(string: String) -> [Int] {
        var indices = [Int]()
        var start = startIndex
        while start < endIndex, let range = range(of: string, range: start..<endIndex), !range.isEmpty {
            indices.append(distance(from: startIndex, to: range.lowerBound))
            start = range.upperBound
        }
        return indices
    }
    
    var containsChinese: Bool {
        contains { $0.isChinese }
    }
    
    var containsEmoji: Bool {
        contains { $0.isEmoji }
    }
}
