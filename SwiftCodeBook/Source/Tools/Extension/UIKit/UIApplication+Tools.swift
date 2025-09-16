//
//  UIApplication+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Combine
import UIKit

public extension UIApplication {
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var interfaceOrientation: UIInterfaceOrientation {
        keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }

    @available(iOSApplicationExtension, unavailable, message: "unavailable in iOS App extension.")
    var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never> {
        #if os(iOS)
            NotificationCenter
                .default
                .publisher(for: UIDevice.orientationDidChangeNotification)
                .map({ _ in UIApplication.shared.interfaceOrientation })
                .removeDuplicates()
                .eraseToAnyPublisher()
        #else
            Empty().eraseToAnyPublisher()
        #endif
    }

    static var appIcon: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [AnyHashable: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [AnyHashable: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconName = iconFiles.last else {
            return nil
        }
        return UIImage(named: iconName)
    }()
    
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
