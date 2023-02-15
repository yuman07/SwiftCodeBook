//
//  Encodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Encodable {
    private func toJSONDataAndObj() -> (data: Data, obj: Any)? {
        if let data = self as? Data {
            return (try? JSONSerialization.jsonObject(with: data)).flatMap { (data, $0) }
        } else if let string = self as? String  {
            return string.data(using: .utf8)?.toJSONDataAndObj()
        } else {
            return (try? JSONEncoder().encode(self))?.toJSONDataAndObj()
        }
    }
    
    func toJSONData() -> Data? {
        toJSONDataAndObj()?.data
    }
    
    func toJSONArray() -> [Any]? {
        guard let array = toJSONDataAndObj()?.obj as? [Any] else { return nil }
        return array
    }
    
    func toJSONDictionary() -> [String: Any]? {
        guard let dict = toJSONDataAndObj()?.obj as? [String: Any] else { return nil }
        return dict
    }
    
    func toJSONString() -> String? {
        guard let data = toJSONData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
