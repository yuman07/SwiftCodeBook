//
//  Encodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension Encodable {
    func toJSONData() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    func toJSONDictionary() -> [String: Any]? {
        guard let data = toJSONData() else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    func toJSONString() -> String? {
        guard let data = toJSONData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
