//
//  Decodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension Decodable {
    init?(JSONData: Data) {
        guard let value = try? JSONDecoder().decode(Self.self, from: JSONData) else { return nil }
        self = value
    }
    
    init?(JSONDictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: JSONDictionary) else { return nil }
        self.init(JSONData: data)
    }
    
    init?(JSONString: String) {
        guard let data = JSONString.data(using: .utf8) else { return nil }
        self.init(JSONData: data)
    }
}
