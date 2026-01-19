//
//  Data+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Foundation

public extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm) throws -> Self {
        try (self as NSData).compressed(using: algorithm) as Data
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Self {
        try (self as NSData).decompressed(using: algorithm) as Data
    }
}
