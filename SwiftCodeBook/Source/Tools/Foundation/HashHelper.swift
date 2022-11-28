//
//  HashHelper.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/28.
//

import CryptoKit
import Foundation

final class HashHelper {
    enum Algorithm {
        case md5
        case sha1
        case sha256
        case sha384
        case sha512
    }
    
    let algorithm: Algorithm
    private var hasher: any HashFunction
    private let queue = DispatchQueue(label: String(format: "%@.HashHelper.SerialQueue", UUID().uuidString))
   
    init(algorithm: Algorithm) {
        self.algorithm = algorithm
        hasher = Self.hasher(using: algorithm)
    }
    
    func update(data: Data) {
        queue.async { [weak self] in
            self?.hasher.update(data: data)
        }
    }
    
    func finalize() -> String {
        queue.sync {
            hasher.finalize().toHashString()
        }
    }
    
    private static func hasher(using algorithm: Algorithm) -> any HashFunction {
        switch algorithm {
        case .md5:
            return Insecure.MD5()
        case .sha1:
            return Insecure.SHA1()
        case .sha256:
            return SHA256()
        case .sha384:
            return SHA384()
        case .sha512:
            return SHA512()
        }
    }
}

extension HashHelper {
    static func hash(data: Data, using algorithm: Algorithm) -> String {
        var hasher = hasher(using: algorithm)
        hasher.update(data: data)
        return hasher.finalize().toHashString()
    }
    
    static func hash(string: String, using algorithm: Algorithm) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        return hash(data: data, using: algorithm)
    }
    
    static func hash(filePath: String, using algorithm: Algorithm) -> String? {
        guard let handler = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handler.close() }
        
        var isEnd = false
        var hasher = hasher(using: algorithm)
        while !isEnd {
            autoreleasepool {
                guard let data = try? handler.read(upToCount: 8192), !data.isEmpty else { return isEnd = true }
                hasher.update(data: data)
            }
        }
        return hasher.finalize().toHashString()
    }
}

extension String {
    func hash(using algorithm: HashHelper.Algorithm) -> String? {
        HashHelper.hash(string: self, using: algorithm)
    }
}

extension Data {
    func hash(using algorithm: HashHelper.Algorithm) -> String {
        HashHelper.hash(data: self, using: algorithm)
    }
}

private extension Digest {
    func toHashString() -> String {
        withUnsafeBytes {
            $0.reduce(into: "") { result, byte in
                result += String(format: "%02x", UInt8(byte))
            }
        }
    }
}
