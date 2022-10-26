//
//  UIDevice+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

extension UIDevice {
    var isSimulator: Bool {
    #if targetEnvironment(simulator)
        true
    #else
        false
    #endif
    }
    
    var deviceModel: String {
        if isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map { $0.value } as? [CChar]) ?? []
            return String(cString: chars)
        }
    }
    
    var is64BitDevice: Bool {
        CGFLOAT_IS_DOUBLE == 1
    }
    
    var isNotchScreen: Bool {
        userInterfaceIdiom == .phone && hasHomeIndicator
    }
    
    var hasHomeIndicator: Bool {
        UIApplication.shared.keyWindow.flatMap { $0.safeAreaInsets.bottom > 0 } ?? false
    }
}
