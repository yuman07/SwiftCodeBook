//
//  Dictionary+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Dictionary {
    func toJSONData(JSONEncoder: JSONEncoder = JSONEncoder()) -> Data? {
        if JSONSerialization.isValidJSONObject(self) {
            return try? JSONSerialization.data(withJSONObject: self)
        } else if let encode = self as? Encodable {
            return encode.toJSONData(JSONEncoder: JSONEncoder)
        }
        return nil
    }
    
    func toJSONString(JSONEncoder: JSONEncoder = JSONEncoder()) -> String? {
        toJSONData(JSONEncoder: JSONEncoder).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    mutating func removeAll(where shouldBeRemoved: (Key, Value) throws -> Bool) rethrows {
        let keys = try reduce(into: [Key]()) { partialResult, element in
            if try shouldBeRemoved(element.key, element.value) {
                partialResult.append(element.key)
            }
        }
        for key in keys {
            removeValue(forKey: key)
        }
    }
}

public extension Dictionary {
    init?(plistFilePath: String) {
        guard let dict = NSDictionary(contentsOfFile: plistFilePath) as? [Key: Value] else { return nil }
        self = dict
    }
}
