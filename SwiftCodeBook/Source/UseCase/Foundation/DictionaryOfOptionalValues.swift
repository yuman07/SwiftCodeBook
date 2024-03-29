//
//  DictionaryOfOptionalValues.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import Foundation

func testDictionaryOfOptionalValues() {
    // 通常情况下Dict的value是非可选的，此时给key赋值nil等于remove该key
    var dictNormal: [String: Int] = ["a": 1, "b": 2]
    dictNormal["a"] = nil
    // ["b": 2]
    print(dictNormal)
    
    // 但如果该Dict的value是可选值，此时一定要注意
    // ["a": Optional(1), "c": nil, "b": Optional(2)]
    var dict: [String: Int?] = ["a": 1, "b": 2, "c": nil]
    print(dict)

    // 对于这种Dict，直接给key赋值nil，也等于直接删除该key
    // ["c": nil, "b": Optional(2)]
    dict["a"] = nil
    print(dict)

    // 如果你想要给这种Dict的某个key设置可选值为nil，需要这样操作
    // // ["c": nil, "a": nil, "b": Optional(2)]
    dict["a"] = .some(nil)
    print(dict)
    
    // 同样，如果你想新增一个value为nil的值
    // ["b": Optional(2), "a": Optional(1), "d": nil, "c": nil]
    dict["d"] = .some(nil)
    print(dict)
}
