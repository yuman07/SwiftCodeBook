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
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

@frozen public enum CurrentApplication: Sendable {
#if canImport(AppKit)
    public static var appIcon: NSImage? {
        NSApplication.shared.applicationIconImage
    }
#elseif canImport(UIKit)
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
    @available(iOSApplicationExtension, unavailable)
    public static var keyWindow: UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
#endif
    
    @MainActor
    @available(iOSApplicationExtension, unavailable)
    public static var keyWindowSize: CGSize? {
#if os(watchOS)
        WKInterfaceDevice.current().screenBounds.size
#else
        keyWindow?.frame.size
#endif
    }
    
    @MainActor
    @available(iOSApplicationExtension, unavailable)
    public static var interfaceOrientation: UIInterfaceOrientation {
#if os(iOS) || os(visionOS)
        keyWindow?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
#else
        .portrait
#endif
    }
    
    @MainActor
    @available(iOSApplicationExtension, unavailable)
    public static var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never> {
#if os(iOS)
        NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIScene.didActivateNotification))
            .receive(on: DispatchQueue.main)
            .compactMap({ _ in keyWindow?.windowScene })
            .flatMap({ $0.publisher(for: \.effectiveGeometry) })
            .map({ _ in interfaceOrientation })
            .removeDuplicates()
            .eraseToAnyPublisher()
#else
        Empty().eraseToAnyPublisher()
#endif
    }
    
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

#if os(iOS) || os(visionOS)
#else
public enum UIInterfaceOrientation: Int, Sendable {
    case unknown = 0
    case portrait = 1
    case portraitUpsideDown = 2
    case landscapeLeft = 4
    case landscapeRight = 3
    
    public var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
    
    public var isLandscape: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }
}
#endif
