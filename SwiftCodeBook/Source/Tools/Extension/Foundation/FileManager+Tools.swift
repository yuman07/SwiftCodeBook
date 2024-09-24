//
//  FileManager+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension FileManager {
    var homePath: String {
        enum Once {
            static let homePath = NSHomeDirectory()
        }
        return Once.homePath
    }
    
    var documentPath: String? {
        enum Once {
            static let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        }
        return Once.documentPath
    }
    
    var libraryPath: String? {
        enum Once {
            static let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
        }
        return Once.libraryPath
    }
    
    var cachePath: String? {
        enum Once {
            static let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
        }
        return Once.cachePath
    }
    
    var tmpPath: String {
        enum Once {
            static let tmpPath = NSTemporaryDirectory()
        }
        return Once.tmpPath
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
    
    func directorySizeInByte(at path: String) async -> UInt64 {
        let sizeActor = SizeActor()
        guard !path.isEmpty, let contents = try? subpathsOfDirectory(atPath: path), !contents.isEmpty else {
            return 0
        }
        for content in contents {
            let filePath = path + "/\(content)"
            await sizeActor.addSize(at: filePath)
        }
        return await sizeActor.size
    }
}

private final actor SizeActor {
    var size = UInt64.zero
    func addSize(at filePath: String) {
        size += ((try? FileManager.default.attributesOfItem(atPath: filePath))?[.size] as? UInt64) ?? 0
    }
}
