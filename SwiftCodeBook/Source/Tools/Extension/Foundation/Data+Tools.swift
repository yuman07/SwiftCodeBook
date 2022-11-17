//
//  Data+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/17.
//

import Foundation

extension Data {
    func toZipped() -> Data? {
        try? (self as NSData).compressed(using: .zlib) as Data
    }
    
    func toUnZipped() -> Data? {
        try? (self as NSData).decompressed(using: .zlib) as Data
    }
}
