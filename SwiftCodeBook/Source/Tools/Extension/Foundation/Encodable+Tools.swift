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
            return Data(string.utf8).toJSONDataAndObj()
        } else {
            return (try? JSONEncoder().encode(self))?.toJSONDataAndObj()
        }
    }
    
    func toJSONData() -> Data? {
        toJSONDataAndObj()?.data
    }
    
    func toJSONArray() -> [Any]? {
        toJSONDataAndObj()?.obj as? [Any]
    }
    
    func toJSONDictionary() -> [String: Any]? {
        toJSONDataAndObj()?.obj as? [String: Any]
    }
    
    func toJSONString() -> String? {
        toJSONData().flatMap { String(data: $0, encoding: .utf8) }
    }
}
