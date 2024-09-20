//
//  NSRange-SwiftRange.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import Foundation

// It must be satisfied that the range and string in the conversion method are the corresponding pair at the beginning.
// If the string changes after getting the range, it will crash when converted to NSRange
func SwiftRangeToNSRange() {
    let string = "好😁123"
    let range = string.startIndex...string.index(string.startIndex, offsetBy: 3)
    
    let nsRange = NSRange(range, in: string)
    
    print(nsRange)
}

func NSRangeToSwiftRange() {
    let string = "好😁123"
    let nsRange = NSRange(location: 0, length: 3)
    
    if let range = Range(nsRange, in: string) {
        print(string[range])
    } else {
        print("fail")
    }
}
