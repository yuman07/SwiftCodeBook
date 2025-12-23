//
//  FileManager+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension FileManager {
    var homePath: String {
        NSHomeDirectory()
    }
    
    var documentPath: String? {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
    
    var libraryPath: String? {
        NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
    }
    
    var cachePath: String? {
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
    }
    
    var tmpPath: String {
        NSTemporaryDirectory()
    }
    
    func directoryExists(at path: String) -> Bool {
        var isDir = ObjCBool(false)
        let exist = fileExists(atPath: path, isDirectory: &isDir)
        return exist && isDir.boolValue
    }
    
    func normalFileExists(at path: String) -> Bool {
        var isDir = ObjCBool(false)
        let exist = fileExists(atPath: path, isDirectory: &isDir)
        return exist && !isDir.boolValue
    }
    
    @concurrent
    func sizeInByte(at path: String) async throws -> (logicalSize: UInt64, onDiskSize: UInt64) {
        try Task.checkCancellation()
        
        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .totalFileSizeKey,
            .fileAllocatedSizeKey,
            .totalFileAllocatedSizeKey,
        ]
        
        guard case let root = URL(fileURLWithPath: path),
              let enumerator = enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [],
                errorHandler: { _, _ in true }
              )
        else { return (0, 0) }
        
        var logicalSize = UInt64.zero
        var onDiskSize = UInt64.zero
        
        if let values = try? root.resourceValues(forKeys: keys) {
            logicalSize += max(0, UInt64(values.totalFileSize ?? values.fileSize ?? 0))
            onDiskSize += max(0, UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0))
        }
        
        while let obj = enumerator.nextObject() {
            try Task.checkCancellation()
            guard let url = obj as? URL else { continue }
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            logicalSize += UInt64(max(0, values.totalFileSize ?? values.fileSize ?? 0))
            onDiskSize += UInt64(max(0, values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0))
        }
        
        return (logicalSize, onDiskSize)
    }
}
