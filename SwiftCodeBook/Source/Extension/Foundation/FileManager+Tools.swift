//
//  FileManager+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension FileManager {
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
    
    func folderSizeAt(path: String) -> UInt64 {
        guard let contents = try? FileManager.default.subpathsOfDirectory(atPath: path), !contents.isEmpty else { return 0 }
        return contents.reduce(into: UInt64.zero) {
            $0 += ((try? FileManager.default.attributesOfItem(atPath: path + "/\($1)"))?[.size] as? UInt64) ?? 0
        }
    }
}
