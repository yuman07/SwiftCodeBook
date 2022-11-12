//
//  JSONObjectCodableTest.swift
//  SwiftCodeBookTests
//
//  Created by yuman on 2022/11/12.
//

import XCTest

private struct JSONDictItem: Codable {
    let ext: JSONDictionaryCodable
}

private let json1 = """
{
    "ext": {
        "id": 1234,
        "name": "yuman",
        "length": "789.56",
        "some": null,
        "array": ["1", 2, 3.3, ["4", {"A1": "哈哈"}]],
        "attribute": {
            "h1": "👌🏻",
            "h2": 111,
            "h3": {
                "p1": "你好",
                "p2": ["地球", "火星"],
                "p3": null,
                "p4": true,
                "p5": []
            },
            "h4": {}
        }
    }
}
"""

private let json2 = """
    [
    111,
    "yuman",
    true,
    null,
    ["h2", {"ll": false}, []],
    {"h3": "2", "array": ["o1", null, 3.14], "ss": {}}
    ]
"""

final class JSONObjectCodableTest: XCTestCase {
    func testDict() {
        let item = JSONDictItem(JSONString: json1)
        XCTAssertNotNil(item)
        
        let dic = item!.toJSONDictionary()!
        XCTAssertTrue((dic as NSDictionary).isEqual(to: json1.toJSONDictionary()!))
    }
    
    func testArray() {
        let item = JSONArrayCodable.init(JSONString: json2)
        XCTAssertNotNil(item)
        XCTAssertTrue((item!.value as NSArray).isEqual(to: json2.toJSONArray()!))
    }
}
