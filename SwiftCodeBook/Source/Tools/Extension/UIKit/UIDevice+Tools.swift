//
//  UIDevice+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

extension UIDevice {
    var isSimulator: Bool {
        Self.isSimulator
    }
    
    var deviceModel: String {
        Self.deviceModel
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
    
    var applicationUsedMemory: UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        return (result == KERN_SUCCESS) ? UInt64(info.phys_footprint) : nil
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
