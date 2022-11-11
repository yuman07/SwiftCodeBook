//
//  Array+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        guard count > 1 else { return self }
        var set = Set<Element>(minimumCapacity: count)
        return filter { set.insert($0).inserted }
    }
}
