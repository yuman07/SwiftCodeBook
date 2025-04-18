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
