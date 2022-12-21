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
    
    @available(iOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(watchOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(tvOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(macOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(macCatalystApplicationExtension, unavailable, message: "Not available in app extensions.")
    var isNotchScreen: Bool {
        userInterfaceIdiom == .phone && hasHomeIndicator
    }
    
    @available(iOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(watchOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(tvOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(macOSApplicationExtension, unavailable, message: "Not available in app extensions.")
    @available(macCatalystApplicationExtension, unavailable, message: "Not available in app extensions.")
    var hasHomeIndicator: Bool {
        UIApplication.shared.keyWindow.flatMap { $0.safeAreaInsets.bottom > 0 } ?? false
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
