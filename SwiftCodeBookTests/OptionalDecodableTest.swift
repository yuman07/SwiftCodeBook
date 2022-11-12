//
//  OptionalDecodableTest.swift
//  SwiftCodeBookTests
//
//  Created by yuman on 2022/11/12.
//

import XCTest

private struct Item: Codable {
    let id: String
    let name: String
}

private let json = """
    [{"id": "100"}, {"id": "200", "name": "yuman"}]
"""

final class OptionalDecodableTest: XCTestCase {
    func test() {
        let data = json.toJSONData()
        XCTAssertNotNil(data)
        
        // array1 nil, because the first item in the list lacks name, the entire list decode fails
        let array1 = try? JSONDecoder().decode([Item].self, from: data!)
        XCTAssertNil(array1)
        
        // array2 is not nil and has exactly two items
        let array2 = try? JSONDecoder().decode([OptionalDecodable<Item>].self, from: data!)
        XCTAssertNotNil(array2)
        XCTAssertTrue(array2!.count == 2)
        
        // Ans has only one item, which is the second item in the list.
        // That is, when decoding an array, the failed items are successfully filtered, and only the decoded ones are left.
        let array3 = array2!.compactMap(\.value)
        XCTAssertTrue(array3.count == 1)
        XCTAssertTrue(array3.first!.id == "200")
    }
}
