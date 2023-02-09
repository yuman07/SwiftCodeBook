//
//  Collection+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/9.
//

import Foundation

public extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
