//
//  Array+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Array {
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
}

public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public extension Array {
    init?(plistFilePath: String) {
        guard let array = NSArray(contentsOfFile: plistFilePath) as? [Element] else { return nil }
        self = array
    }
}

public extension Array where Element: Equatable {
    func removeDuplicates() -> [Element] {
        guard count > 1 else { return self }
        return reduce(into: []) {
            if !$0.contains($1) { $0.append($1) }
        }
    }
}

public extension Array where Element: Hashable {
    func removeDuplicates() -> [Element] {
        guard count > 1 else { return self }
        var set = Set<Element>(minimumCapacity: count)
        return filter { set.insert($0).inserted }
    }
}
