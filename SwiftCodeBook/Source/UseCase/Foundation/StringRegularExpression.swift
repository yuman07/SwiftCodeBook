//
//  StringRegularExpression.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/18.
//

import Foundation

func testStringRegularExpression() {
    var string = "yuman[3](hahah), manyu[10](lplplp), hahfsd[123](sdddd)"
    
    if case let ranges = string.ranges(of: #"\[[0-9]+\]\([\S]+\)"#, options: .regularExpression), !ranges.isEmpty {
        var count = ranges.count
        for range in ranges.reversed() {
            if let numRange = string.range(of: "[0-9]+", options: .regularExpression, range: range) {
                string.replaceSubrange(numRange, with: "\(count)")
            }
            count -= 1
        }
    } else {
        print("nil")
    }
    print(string)
}
