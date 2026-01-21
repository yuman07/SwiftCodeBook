//
//  Array+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Array {
    func toJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: self)
    }
    
    func toJSONString() -> String? {
        toJSONData().flatMap { String(data: $0, encoding: .utf8) }
    }
}

public extension Array {
    func safeValue(at index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

public extension Array {
    init?(plistFilePath: String) {
        guard let array = NSArray(contentsOfFile: plistFilePath) as? [Element] else { return nil }
        self = array
    }
}

public extension Array where Element: Equatable {
    func removingDuplicates() -> [Element] {
        guard count > 1 else { return self }
        return reduce(into: []) {
            if !$0.contains($1) { $0.append($1) }
        }
    }
}

public extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        guard count > 1 else { return self }
        var set = Set<Element>(minimumCapacity: count)
        return filter { set.insert($0).inserted }
    }
}
