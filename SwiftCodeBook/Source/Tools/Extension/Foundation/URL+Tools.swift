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
    
    mutating func updateQueryDictionary(_ dict: [String: String]) {
        guard var urlComponents = URLComponents(string: absoluteString) else { return }
        urlComponents.queryItems = dict.map { URLQueryItem(name: $0.key, value: $0.value) }
        self = urlComponents.url ?? self
    }
}
