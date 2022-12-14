//
//  DictionaryOfOptionalValues.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import Foundation

func DictionaryOfOptionalValues() {
    // Under normal circumstances, the value of Dictionary is not optional.
    // At this time, setting nil for a key is equivalent to deleting the key.
    var dictNormal = ["a": 1, "b": 2]
    dictNormal["a"] = nil
    // ["b": 2]
    print(dictNormal)
    
    // But pay attention when the value of a Dictionary is an Optional type
    // [String: Int?]
    // ["a": Optional(1), "c": nil, "b": Optional(2)]
    var dict = [
                "a": 1,
                "b": 2,
                "c": nil,
            ]
    print(dict)

    // Still equivalent to deleting the key as "a"
    // ["c": nil, "b": Optional(2)]
    dict["a"] = nil
    print(dict)

    // If you want to set nil to a
    // // ["c": nil, "a": nil, "b": Optional(2)]
    dict["a"] = .some(nil)
    print(dict)
    
    // If you need to add a new key, its value is nil
    // ["b": Optional(2), "a": Optional(1), "d": nil, "c": nil]
    dict["d"] = .some(nil)
    print(dict)
}
