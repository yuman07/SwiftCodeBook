//
//  Array+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Array {
    func toJSONData() -> Data? {
        if JSONSerialization.isValidJSONObject(self) {
            return try? JSONSerialization.data(withJSONObject: self)
        } else if let encode = self as? Encodable {
            return encode.toJSONData()
        }
        return nil
    }
    
    func toJSONString() -> String? {
        guard let data = toJSONData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public extension Array where Element: Hashable {
    func unique() -> [Element] {
        guard count > 1 else { return self }
        var set = Set<Element>(minimumCapacity: count)
        return filter { set.insert($0).inserted }
    }
}
