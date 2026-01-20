//
//  CurrentApplication.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Combine
import Foundation

#if canImport(Darwin)
import Darwin
#endif

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@frozen public enum CurrentApplication: Sendable {
#if os(macOS)
    public static var appIcon: NSImage? {
        NSApplication.shared.applicationIconImage
    }
#else
    public static var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [AnyHashable: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [AnyHashable: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconName = iconFiles.last else {
            return nil
        }
        return UIImage(named: iconName)
    }
#endif

#if os(macOS)
    @MainActor
    public static var keyWindow: NSWindow? {
        NSApplication.shared.keyWindow
    }
#elseif os(iOS) || os(tvOS) || os(visionOS)
    @MainActor
    public static var keyWindow: UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
#endif

#if os(iOS) || os(visionOS)
    @MainActor
    public static var interfaceOrientation: UIInterfaceOrientation {
        keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }
#endif

#if os(iOS) || os(visionOS)
    @MainActor
    public static var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never> {
#if os(iOS)
        return NotificationCenter
            .default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .map({ _ in interfaceOrientation })
            .removeDuplicates()
            .eraseToAnyPublisher()
#else
        return Empty().eraseToAnyPublisher()
#endif
    }
#endif

    public static var appDisplayName: String?  {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
    }
    
    public static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    public static var appBuildNumber: Int? {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap { Int($0) }
    }
    
    public static var appBundleIdentifier: String? {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
    }
    
    public static var usedMemoryInByte: UInt64? {
#if canImport(Darwin)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return (result == KERN_SUCCESS) ? UInt64(info.phys_footprint) : nil
#else
        return nil
#endif
    }
}
