//
//  HashHelper.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/28.
//

import CryptoKit
import Foundation

public final actor HashHelper {
    public enum Function {
        case md5
        case sha1
        case sha256
        case sha384
        case sha512
        
        fileprivate var hasher: any HashFunction {
            switch self {
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
    
    private let function: Function
    private var hasher: any HashFunction
    
    public init(function: Function) {
        self.function = function
        hasher = function.hasher
    }
    
    public func reset() {
        hasher = function.hasher
    }
    
    public func update(data: Data) {
        hasher.update(data: data)
    }
    
    public func finalize() -> String {
        hasher.finalize().toHashString()
    }
}

public extension HashHelper {
    static func hash(data: Data, using function: Function) -> String {
        var hasher = function.hasher
        hasher.update(data: data)
        return hasher.finalize().toHashString()
    }
    
    static func hash(string: String, using function: Function) -> String {
        hash(data: Data(string.utf8), using: function)
    }
    
    static func hash(filePath: String, using function: Function) async -> String? {
        await withUnsafeContinuation { continuation in
            DispatchQueue.global().async {
                guard let handler = FileHandle(forReadingAtPath: filePath) else { return continuation.resume(returning: nil) }
                defer { try? handler.close() }
                
                var isEnd = false
                var hasher = function.hasher
                while !isEnd {
                    autoreleasepool {
                        guard let data = try? handler.read(upToCount: 8192), !data.isEmpty else { return isEnd = true }
                        hasher.update(data: data)
                    }
                }
                
                return continuation.resume(returning: hasher.finalize().toHashString())
            }
        }
    }
}

public extension String {
    func hash(using function: HashHelper.Function) -> String {
        HashHelper.hash(string: self, using: function)
    }
}

public extension Data {
    func hash(using function: HashHelper.Function) -> String {
        HashHelper.hash(data: self, using: function)
    }
}

private extension Digest {
    func toHashString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
