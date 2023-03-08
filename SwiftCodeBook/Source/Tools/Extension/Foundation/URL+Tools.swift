//
//  URL+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/3.
//

import Foundation

public extension URL {
    var queryDictionary: [String: String] {
        (URLComponents(string: absoluteString)?.queryItems ?? []).reduce(into: [:]) {
            if let value = $1.value { $0[$1.name] = value }
        }
    }
}
