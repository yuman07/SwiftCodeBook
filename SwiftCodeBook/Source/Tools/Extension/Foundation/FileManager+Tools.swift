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
    
    var documentPath: String {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? homePath + "/Documents"
    }
    
    var libraryPath: String {
        NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? homePath + "/Library"
    }
    
    var cachePath: String {
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? libraryPath + "/Caches"
    }
    
    var tmpPath: String {
        NSTemporaryDirectory()
    }
    
    func directoryExists(atPath: String) -> Bool {
        var isDir = ObjCBool(false)
        let exist = fileExists(atPath: atPath, isDirectory: &isDir)
        return exist && isDir.boolValue
    }
    
    func normalFileExists(atPath: String) -> Bool {
        var isDir = ObjCBool(false)
        let exist = fileExists(atPath: atPath, isDirectory: &isDir)
        return exist && !isDir.boolValue
    }
    
    func folderSizeAt(path: String) async -> UInt64 {
        await withUnsafeContinuation { continuation in
            Task.detached {
                guard !path.isEmpty, let contents = try? FileManager.default.subpathsOfDirectory(atPath: path), !contents.isEmpty else {
                    return continuation.resume(returning: 0)
                }
                continuation.resume(returning: contents.reduce(into: UInt64.zero) {
                    $0 += ((try? FileManager.default.attributesOfItem(atPath: path + "/\($1)"))?[.size] as? UInt64) ?? 0
                })
            }
        }
    }
}
