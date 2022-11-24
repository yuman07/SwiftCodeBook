//
//  Data+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/17.
//

import Foundation

extension Data {
    var isZipped: Bool {
        guard count >= 2 else { return false }
        return self[0] == 0x1f && self[1] == 0x8b
    }
    
    func toZipped(zipAnyway: Bool = false) -> Data? {
        if !zipAnyway && isZipped { return self }
        return try? (self as NSData).compressed(using: .zlib) as Data
    }
    
    func toUnZipped(allowRecursive: Bool = true) -> Data? {
        var data: Data? = self
        while let d = data, d.isZipped {
            data = try? (self as NSData).decompressed(using: .zlib) as Data
            guard allowRecursive else { break }
        }
        return data
    }
}
