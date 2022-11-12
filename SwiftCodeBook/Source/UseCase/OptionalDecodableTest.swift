//
//  OptionalDecodableTest.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/12.
//

import Foundation

struct Item: Codable {
    let id: String
    let name: String
}

let list = [
    ["id": "100"],
    ["id": "200", "name": "yuman"]
]

struct OptionalDecodableTest {
    init() {
        guard let data = try? JSONSerialization.data(withJSONObject: list) else { return }
        
        // this is nil, because the first item in the list lacks name, the entire list decode fails
        _ = try? JSONDecoder().decode([Item].self, from: data)
        
        // array is not nil and has exactly two items
        let array = try? JSONDecoder().decode([OptionalDecodable<Item>].self, from: data)
        
        if let array {
            // Ans has only one item, which is the second item in the list.
            // That is, when decoding an array, the failed items are successfully filtered, and only the decoded ones are left.
            let ans = array.compactMap(\.value)
            print(ans)
        }
    }
}
