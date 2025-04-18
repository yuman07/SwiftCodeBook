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
    
    func queryItemValue(forKey key: String) -> String? {
        queryDictionary[key]
    }
    
    func setQueryItemValue(_ value: String, forKey key: String) -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        var queryDict = queryDictionary
        queryDict[key] = value
        components.queryItems = queryDict.map { queryKey, queryValue in
            URLQueryItem(name: queryKey, value: queryValue)
        }
        return components.url ?? self
    }
    
    func removeQueryItemValue(forKey key: String) -> URL {
        guard var components = URLComponents(string: absoluteString) else {
            return self
        }
        
        var queryDict = queryDictionary
        queryDict.removeValue(forKey: key)
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
