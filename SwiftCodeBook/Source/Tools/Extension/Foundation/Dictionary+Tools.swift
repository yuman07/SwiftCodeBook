//
//  Dictionary+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Dictionary {
    func toJSONData() -> Data? {
        if let data = try? JSONSerialization.data(withJSONObject: self) {
            return data
        } else if let encode = self as? Encodable {
            return encode.toJSONData()
        }
        return nil
    }
    
    func toJSONString() -> String? {
        toJSONData().flatMap { String(data: $0, encoding: .utf8) }
    }
}

public extension Dictionary where Key == String, Value == Any {
    init?(plistFilePath: String) {
        guard let dict = NSDictionary(contentsOfFile: plistFilePath) as? [String: Any] else { return nil }
        self = dict
    }
}
