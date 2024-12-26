//
//  CodableNote.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/12/26.
//

import Foundation

func testOptionalCodable() {
    struct YMModel: Codable {
        let values: [OptionalCodable<Int>]
    }
    
    let json = "{\"values\":[1,2,\"3\"]}"
    let model = YMModel(JSONString: json)
    if let model {
        print(model)
        print(model.toJSONString() ?? "fail")
    }
}
