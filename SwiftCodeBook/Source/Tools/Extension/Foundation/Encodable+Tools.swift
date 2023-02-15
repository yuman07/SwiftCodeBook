//
//  Encodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Encodable {
    func toJSONData() -> Data? {
        if let data = self as? Data {
            return (try? JSONSerialization.jsonObject(with: data)).flatMap { _ in data }
        } else if let string = self as? String  {
            return string.data(using: .utf8)?.toJSONData()
        } else {
            return try? JSONEncoder().encode(self)
        }
    }
    
    func toJSONArray() -> [Any]? {
        guard let data = toJSONData() else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [Any]
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
