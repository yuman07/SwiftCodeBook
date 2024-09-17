//
//  UIApplication+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIApplication {
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var keyWindow: UIWindow? {
        let windows = connectedScenes.compactMap{ $0 as? UIWindowScene }.flatMap(\.windows)
        return windows.count == 1 ? windows.first : windows.first(where: { $0.isKeyWindow })
    }
    
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var interfaceOrientation: UIInterfaceOrientation {
        keyWindow?.windowScene?.interfaceOrientation ?? .unknown
    }
    
    static var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    
    static var appDisplayName: String? = {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
    }()
    
    static var appVersion: String? = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()
    
    static var appBuildNumber: Int? = {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap { Int($0) }
    }()
    
    static var appBundleIdentifier: String? = {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
    }()
    
    static var isAppExtension: Bool = {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }()
    
    static var isRunningTests: Bool {
        ProcessInfo().environment["XCTestConfigurationFilePath"] != nil
    }
    
    static var isAdHocDistributed = {
        Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }()
    
    static var usedMemoryInByte: UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return (result == KERN_SUCCESS) ? UInt64(info.phys_footprint) : nil
    }
}
