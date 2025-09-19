//
//  HashHandler.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/28.
//

import CryptoKit
import Foundation

public final class HashHandler {
    @frozen public enum Function: Sendable {
        case md5
        case sha1
        case sha256
        case sha384
        case sha512
    }
    
    private let function: Function
    private var hasher: any HashFunction
    
    public init(function: Function) {
        self.function = function
        hasher = function.hasher
    }
    
    public func update(data: Data) {
        hasher.update(data: data)
    }
    
    public func finalize() -> String {
        hasher.finalize().toHashString()
    }
    
    public func reset() {
        hasher = function.hasher
    }
}

public extension HashHandler {
    static func hash(data: Data, using function: Function) -> String {
        var hasher = function.hasher
        hasher.update(data: data)
        return hasher.finalize().toHashString()
    }
    
    static func hash(string: String, using function: Function) -> String {
        hash(data: Data(string.utf8), using: function)
    }
    
    @concurrent
    static func hash(filePath: String, using function: Function) async throws -> String {
        try Task.checkCancellation()
        let handler = try FileHandle(forReadingFrom: URL(filePath: filePath))
        defer { try? handler.close() }
        
        var isEnd = false
        var hasher = function.hasher
        while !isEnd {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let data = try handler.read(upToCount: 16384), !data.isEmpty else { return isEnd = true }
                hasher.update(data: data)
            }
        }
        
        try Task.checkCancellation()
        return hasher.finalize().toHashString()
    }
}

public extension String {
    func hash(using function: HashHandler.Function) -> String {
        HashHandler.hash(string: self, using: function)
    }
}

public extension Data {
    func hash(using function: HashHandler.Function) -> String {
        HashHandler.hash(data: self, using: function)
    }
}

private extension HashHandler.Function {
    var hasher: any HashFunction {
        switch self {
        case .md5: Insecure.MD5()
        case .sha1: Insecure.SHA1()
        case .sha256: SHA256()
        case .sha384: SHA384()
        case .sha512: SHA512()
        }
    }
}

private extension Digest {
    func toHashString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
