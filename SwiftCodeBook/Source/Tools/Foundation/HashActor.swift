//
//  HashActor.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/28.
//

import CryptoKit
import Foundation

public final actor HashActor {
    public enum Function {
        case md5
        case sha1
        case sha256
        case sha384
        case sha512
        
        fileprivate var hasher: any HashFunction {
            switch self {
            case .md5: Insecure.MD5()
            case .sha1: Insecure.SHA1()
            case .sha256: SHA256()
            case .sha384: SHA384()
            case .sha512: SHA512()
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

public extension HashActor {
    static func hash(data: Data, using function: Function) -> String {
        var hasher = function.hasher
        hasher.update(data: data)
        return hasher.finalize().toHashString()
    }
    
    static func hash(string: String, using function: Function) -> String {
        hash(data: Data(string.utf8), using: function)
    }
    
    static func hash(filePath: String, using function: Function) async -> String? {
        let hasher = HashActor(function: function)
        guard let handler = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handler.close() }
        
        var isEnd = false
        while !isEnd {
            var task: Task<Void, Never>?
            autoreleasepool {
                task = Task {
                    guard let data = try? handler.read(upToCount: 8192), !data.isEmpty else { return isEnd = true }
                    await hasher.update(data: data)
                }
            }
            _ = await task?.value
        }
        
        return await hasher.finalize()
    }
}

public extension String {
    func hash(using function: HashActor.Function) -> String {
        HashActor.hash(string: self, using: function)
    }
}

public extension Data {
    func hash(using function: HashActor.Function) -> String {
        HashActor.hash(data: self, using: function)
    }
}

private extension Digest {
    func toHashString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
