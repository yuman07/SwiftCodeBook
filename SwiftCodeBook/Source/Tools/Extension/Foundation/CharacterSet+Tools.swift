//
//  CharacterSet+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/8/17.
//

import Foundation

public extension CharacterSet {
    static let rfc3986Allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
}
