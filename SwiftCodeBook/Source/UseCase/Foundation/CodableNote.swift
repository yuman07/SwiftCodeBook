//
//  CodableNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/12/26.
//

import Foundation

func testOptionalCodable() {
    struct YMModel1: Codable {
        let values: [Int]
    }
    struct YMModel2: Codable {
        let values: [OptionalCodable<Int>]
    }
    
    let json = "{\"values\":[1,2,\"3\"]}"
    let model1 = YMModel1(JSONString: json)
    let model2 = YMModel2(JSONString: json)
    if let model1 {
        print(model1)
    } else {
        print("model1 fail")
    }
    if let model2 {
        print(model2)
        print(model2.toJSONString() ?? "fail")
    }
}
