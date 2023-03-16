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
    
    var deviceModel: String {
        enum Once {
            static var deviceModel = {
                if UIDevice.current.isSimulator {
                    return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
                } else {
                    var info = utsname()
                    uname(&info)
                    let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
                    return String(cString: chars)
                }
            }()
        }
        return Once.deviceModel
    }
    
    var is64BitDevice: Bool {
        CGFLOAT_IS_DOUBLE == 1
    }
    
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var isNotchScreen: Bool {
        userInterfaceIdiom == .phone && hasHomeIndicator
    }
    
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var hasHomeIndicator: Bool {
        UIApplication.shared.keyWindow.flatMap { $0.safeAreaInsets.bottom > 0 } ?? false
    }
    
    var totalDiskSpaceInByte: UInt64 {
        enum Once {
            static var totalDiskSpaceInByte = {
                (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64 ?? 0
            }()
        }
        return Once.totalDiskSpaceInByte
    }
    
    var freeDiskSpaceInByte: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64 ?? 0
    }
}
