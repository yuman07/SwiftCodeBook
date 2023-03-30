//
//  Decodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Decodable {
    init?(JSONData: Data, JSONDecoder: JSONDecoder = JSONDecoder()) {
        guard let value = try? JSONDecoder.decode(Self.self, from: JSONData) else { return nil }
        self = value
    }
    
    init?(JSONArray: [Any], JSONDecoder: JSONDecoder = JSONDecoder()) {
        guard JSONSerialization.isValidJSONObject(JSONArray), let data = try? JSONSerialization.data(withJSONObject: JSONArray) else { return nil }
        self.init(JSONData: data, JSONDecoder: JSONDecoder)
    }
    
    init?(JSONDictionary: [AnyHashable: Any], JSONDecoder: JSONDecoder = JSONDecoder()) {
        guard JSONSerialization.isValidJSONObject(JSONDictionary), let data = try? JSONSerialization.data(withJSONObject: JSONDictionary) else { return nil }
        self.init(JSONData: data, JSONDecoder: JSONDecoder)
    }
    
    init?(JSONString: String, JSONDecoder: JSONDecoder = JSONDecoder()) {
        self.init(JSONData: Data(JSONString.utf8), JSONDecoder: JSONDecoder)
    }
}
