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
        
        // array1 nil, because the first item in the list lacks name, the entire list decode fails
        let array1 = try? JSONDecoder().decode([Item].self, from: data)
        if array1 == nil { print("array1 is nil") }
        
        // array2 is not nil and has exactly two items
        let array2 = try? JSONDecoder().decode([OptionalDecodable<Item>].self, from: data)
        
        if let array2 {
            // Ans has only one item, which is the second item in the list.
            // That is, when decoding an array, the failed items are successfully filtered, and only the decoded ones are left.
            let ans = array2.compactMap(\.value)
            print(ans)
        }
    }
}
