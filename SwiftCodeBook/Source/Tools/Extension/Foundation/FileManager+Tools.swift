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
    
    func directorySizeInByte(at path: String) async throws -> UInt64 {
        try Task.checkCancellation()
        guard !path.isEmpty, let contents = try? subpathsOfDirectory(atPath: path), !contents.isEmpty else {
            return 0
        }
        return try contents.reduce(into: 0) { partialResult, file in
            try Task.checkCancellation()
            partialResult += ((try? attributesOfItem(atPath: path + "/\(file)"))?[.size] as? UInt64) ?? 0
        }
    }
}
