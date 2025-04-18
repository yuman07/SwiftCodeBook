//
//  URL+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/3.
//

import Foundation

public extension URL {
    static let blank = URL(string: "about:blank")!
    
    var queryDictionary: [String: String] {
        (URLComponents(string: absoluteString)?.queryItems ?? []).reduce(into: [:]) { dict, item in
            if let value = item.value { dict[item.name] = value }
        }
    }
    
    func appendingQueryItems(
        _ queryItems: [URLQueryItem],
        uniquingKeysWith combine: ((_ key: String, _ currentValue: String, _ newValue: String?) throws -> String?)? = nil
    ) rethrows -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        var queryDict = queryDictionary
        try queryItems.forEach { queryItem in
            let key = queryItem.name
            let currentValue = queryDict[key]
            var newValue = queryItem.value
            if let currentValue, let combine {
                newValue = try combine(key, currentValue, newValue)
            }
            queryDict[key] = newValue
        }
        
        components.queryItems = queryDict.map { queryKey, queryValue in
            URLQueryItem(name: queryKey, value: queryValue)
        }
        return components.url ?? self
    }
    
    func removeQueryItems(forKeys keys: [String]) -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        var queryDict = queryDictionary
        for key in keys { queryDict.removeValue(forKey: key) }
        components.queryItems = queryDict.map { queryKey, queryValue in
            URLQueryItem(name: queryKey, value: queryValue)
        }
        return components.url ?? self
    }
    
    func removeAllQueryItems() -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        components.queryItems = nil
        return components.url ?? self
    }
}
