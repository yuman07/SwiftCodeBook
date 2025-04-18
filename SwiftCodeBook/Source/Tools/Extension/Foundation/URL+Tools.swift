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
}
