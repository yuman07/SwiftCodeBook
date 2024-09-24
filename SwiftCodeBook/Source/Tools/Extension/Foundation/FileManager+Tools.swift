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
        guard !path.isEmpty, let contents = try? subpathsOfDirectory(atPath: path), !contents.isEmpty else {
            return 0
        }
        return contents.reduce(into: 0) { partialResult, file in
            partialResult += ((try? attributesOfItem(atPath: path + "/\(file)"))?[.size] as? UInt64) ?? 0
        }
    }
}
