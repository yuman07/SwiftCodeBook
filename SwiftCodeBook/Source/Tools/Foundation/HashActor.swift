//
//  HashActor.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/28.
//

import CryptoKit
import Foundation

public final class HashHelper: @unchecked Sendable {
    public enum Function {
        case md5
        case sha1
        case sha256
        case sha384
        case sha512
    }
    
    private let function: Function
    private let queue = DispatchQueue(label: "com.HashActor.serialQueue")
    private var hasher: any HashFunction
    
    public init(function: Function) {
        self.function = function
        hasher = function.hasher
    }
    
    public func reset() {
        queue.async { [weak self] in
            guard let self else { return }
            hasher = function.hasher
        }
    }
    
    public func update(data: Data) {
        queue.async { [weak self] in
            guard let self else { return }
            hasher.update(data: data)
        }
    }
    
    public func finalize() async -> String {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: "") }
                continuation.resume(returning: hasher.finalize().toHashString())
            }
        }
    }
}

private extension HashHelper.Function {
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
        guard !Task.isCancelled, let handler = FileHandle(forReadingAtPath: filePath) else { return nil }
        defer { try? handler.close() }
        
        var hasher = function.hasher
        var isEnd = false
        var meetError = Task.isCancelled
        while !isEnd && !meetError {
            autoreleasepool {
                guard let data = try? handler.read(upToCount: 16384) else { return meetError = true }
                guard !data.isEmpty else { return isEnd = true }
                hasher.update(data: data)
            }
            meetError = meetError || Task.isCancelled
        }
        
        return meetError ? nil : hasher.finalize().toHashString()
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
