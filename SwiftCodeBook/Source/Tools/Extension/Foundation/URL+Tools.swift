//
//  URL+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/3.
//

import Foundation

public extension URL {
    var queryDictionary: [String: String] {
        (URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems ?? []).reduce(into: [:]) { dict, item in
            if let value = item.value { dict[item.name] = value }
        }
    }
    
    func removingQueryItems(where shouldBeRemoved: (URLQueryItem) throws -> Bool) rethrows -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        
        let queryItems = try (components.queryItems ?? []).compactMap { item in
            try shouldBeRemoved(item) ? nil : URLQueryItem(name: item.name, value: item.value)
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url ?? self
    }
    
    func removingAllQueryItems() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        
        components.queryItems = nil
        return components.url ?? self
    }
}
