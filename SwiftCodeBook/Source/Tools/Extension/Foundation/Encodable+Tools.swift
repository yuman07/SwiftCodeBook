//
//  Encodable+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Encodable {
    private func toJSONDataAndObj(JSONEncoder: JSONEncoder) -> (data: Data, obj: Any)? {
        if let data = self as? Data {
            return (try? JSONSerialization.jsonObject(with: data)).flatMap { (data, $0) }
        } else if let string = self as? String  {
            return Data(string.utf8).toJSONDataAndObj(JSONEncoder: JSONEncoder)
        } else {
            return (try? JSONEncoder.encode(self))?.toJSONDataAndObj(JSONEncoder: JSONEncoder)
        }
    }
    
    func toJSONData(JSONEncoder: JSONEncoder = JSONEncoder()) -> Data? {
        toJSONDataAndObj(JSONEncoder: JSONEncoder)?.data
    }
    
    func toJSONArray(JSONEncoder: JSONEncoder = JSONEncoder()) -> [Any]? {
        toJSONDataAndObj(JSONEncoder: JSONEncoder)?.obj as? [Any]
    }
    
    func toJSONDictionary(JSONEncoder: JSONEncoder = JSONEncoder()) -> [String: Any]? {
        toJSONDataAndObj(JSONEncoder: JSONEncoder)?.obj as? [String: Any]
    }
    
    func toJSONString(JSONEncoder: JSONEncoder = JSONEncoder()) -> String? {
        toJSONData(JSONEncoder: JSONEncoder).flatMap { String(data: $0, encoding: .utf8) }
    }
}
