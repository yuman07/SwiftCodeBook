//
//  Array+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Array {
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

public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public extension Array where Element == Any {
    init?(plistFilePath: String) {
        guard let array = NSArray(contentsOfFile: plistFilePath) as? [Any] else { return nil }
        self = array
    }
}

public extension Array where Element: Equatable {
    func removeDuplicates() -> [Element] {
        guard count > 1 else { return self }
        return reduce(into: [Element]()) {
            guard !$0.contains($1) else { return }
            $0.append($1)
        }
    }
    
    mutating func remove(element: Element) {
        guard let index = firstIndex(of: element) else { return }
        remove(at: index)
    }
}

public extension Array where Element: Hashable {
    func removeDuplicates() -> [Element] {
        guard count > 1 else { return self }
        var set = Set<Element>(minimumCapacity: count)
        return filter { set.insert($0).inserted }
    }
}
