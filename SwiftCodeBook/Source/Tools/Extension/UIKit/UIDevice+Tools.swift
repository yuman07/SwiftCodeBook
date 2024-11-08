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
        enum Once {
            static let deviceModel = {
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
        enum Once {
            static let is64BitDevice = Int.bitWidth == 64
        }
        return Once.is64BitDevice
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
            static let totalDiskSpaceInByte = {
                (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64 ?? 0
            }()
        }
        return Once.totalDiskSpaceInByte
    }
    
    var freeDiskSpaceInByte: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64 ?? 0
    }
}
