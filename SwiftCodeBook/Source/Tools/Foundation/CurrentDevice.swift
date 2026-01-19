//
//  CurrentDevice.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Foundation

public final class CurrentDevice: Sendable {
    private init() {}
    
    public static var isSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }
    
    // https://www.hubweb.cn
    // https://theapplewiki.com/wiki/Main_Page
    public static var deviceModel: String {
        if isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
            return String(cString: chars)
        }
    }
    
    public static var is64BitDevice: Bool {
        Int.bitWidth == 64
    }
    
    public static var totalDiskSpaceInByte: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64
    }
    
    public static var freeDiskSpaceInByte: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64
    }
}
