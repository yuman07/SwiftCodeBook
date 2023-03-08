//
//  UIDevice+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIDevice {
    var isSimulator: Bool {
        Self.isSimulator
    }
    
    var deviceModel: String {
        Self.deviceModel
    }
    
    var is64BitDevice: Bool {
        CGFLOAT_IS_DOUBLE == 1
    }
    
    @available(iOSApplicationExtension, unavailable, message: "Not available in iOS App extension.")
    var isNotchScreen: Bool {
        userInterfaceIdiom == .phone && hasHomeIndicator
    }
    
    @available(iOSApplicationExtension, unavailable, message: "Not available in iOS App extension.")
    var hasHomeIndicator: Bool {
        UIApplication.shared.keyWindow.flatMap { $0.safeAreaInsets.bottom > 0 } ?? false
    }
    
    var isJailbroken: Bool {
        let canReadBinBash = FileManager.default.fileExists(atPath: "/bin/bash")
        if let cydiaURL = URL(string: "cydia://"), let canOpenCydia = (UIApplication.value(forKey: "sharedApplication") as? UIApplication)?.canOpenURL(cydiaURL) {
            return canOpenCydia || canReadBinBash
        } else {
            return canReadBinBash
        }
    }
    
    var totalDiskSpaceInBytes: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64 ?? 0
    }
    
    var freeDiskSpaceInBytes: UInt64 {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64 ?? 0
    }
}

private extension UIDevice {
    static let isSimulator = {
    #if targetEnvironment(simulator)
        true
    #else
        false
    #endif
    }()
    
    static let deviceModel = {
        if isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
            return String(cString: chars)
        }
    }()
}
