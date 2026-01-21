//
//  Dictionary+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Dictionary {
    func toJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: self)
    }
    
    func toJSONString() -> String? {
        toJSONData().flatMap { String(data: $0, encoding: .utf8) }
    }
}

public extension Dictionary {
    init?(plistFilePath: String) {
        guard let dict = NSDictionary(contentsOfFile: plistFilePath) as? [Key: Value] else { return nil }
        self = dict
    }
}

public extension Dictionary {
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
