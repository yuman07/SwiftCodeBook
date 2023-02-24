//
//  Decodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Decodable {
    init?(JSONData: Data) {
        guard let value = try? JSONDecoder().decode(Self.self, from: JSONData) else { return nil }
        self = value
    }
    
    init?(JSONArray: [Any]) {
        guard let data = JSONArray.toJSONData() else { return nil }
        self.init(JSONData: data)
    }
    
    init?(JSONDictionary: [AnyHashable: Any]) {
        guard let data = JSONDictionary.toJSONData() else { return nil }
        self.init(JSONData: data)
    }
    
    init?(JSONString: String) {
        self.init(JSONData: Data(JSONString.utf8))
    }
}
