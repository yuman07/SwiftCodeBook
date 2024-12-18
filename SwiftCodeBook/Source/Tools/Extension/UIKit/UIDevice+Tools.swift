//
//  UIDevice+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIDevice {
    var isSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }
    
    // https://theapplewiki.com/wiki/Main_Page
    var deviceModel: String {
        if UIDevice.current.isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
            return String(cString: chars)
        }
    }
    
    var is64BitDevice: Bool {
        Int.bitWidth == 64
    }
    
    var totalDiskSpaceInByte: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64 ?? 0
    }
    
    var freeDiskSpaceInByte: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64 ?? 0
    }
}
