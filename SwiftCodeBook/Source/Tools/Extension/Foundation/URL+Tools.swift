//
//  URL+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/3.
//

import Foundation

public extension URL {
    
    static let blank = {
        guard let url = URL(string: "about:blank") else {
            fatalError("blank should be a URL")
        }
        return url
    }
    
    var queryDictionary: [String: String] {
        get {
            (URLComponents(string: absoluteString)?.queryItems ?? []).reduce(into: [:]) {
                if let value = $1.value { $0[$1.name] = value }
            }
        }
        set {
            if var components = URLComponents(string: absoluteString) {
                components.queryItems = newValue.map { URLQueryItem(name: $0.key, value: $0.value) }
                components.url.flatMap { self = $0 }
            }
        }
    }
}
