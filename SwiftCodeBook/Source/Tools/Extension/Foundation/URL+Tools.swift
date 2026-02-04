//
//  URL+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/3.
//

import Foundation

public extension URL {
    var queryDictionary: [String: String] {
        (URLComponents(string: absoluteString)?.queryItems ?? []).reduce(into: [:]) { dict, item in
            if let value = item.value { dict[item.name] = value }
        }
    }
    
    func removingQueryItems(where shouldBeRemoved: (URLQueryItem) throws -> Bool) rethrows -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        components.queryItems = try (components.queryItems ?? []).compactMap { item in
            try shouldBeRemoved(item) ? nil : URLQueryItem(name: item.name, value: item.value)
        }
        return components.url ?? self
    }
    
    func removingAllQueryItems() -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        components.queryItems = nil
        return components.url ?? self
    }
}
