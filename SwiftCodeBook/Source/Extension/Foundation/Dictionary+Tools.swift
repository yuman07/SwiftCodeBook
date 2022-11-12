//
//  Dictionary+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension Dictionary {
    func toJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: self)
    }
    
    func toJSONString() -> String? {
        guard let data = toJSONData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
