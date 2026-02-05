//
//  CurrentApplication.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

#if canImport(AppKit)
import AppKit
#endif
import Combine
#if canImport(Darwin)
import Darwin
#endif
import Foundation
#if canImport(UIKit)
import UIKit
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
        nil
#endif
    }
    
    private static let gcdMemoryWarningPublisher = GCDMemoryWarningPublisher()
    public static var memoryWarningPublisher: AnyPublisher<Void, Never> {
#if os(iOS) || os(tvOS) || os(visionOS)
        let systemNotification = NotificationCenter
            .default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .map({ _ in })
            .eraseToAnyPublisher()
#else
        let systemNotification = Empty().eraseToAnyPublisher()
#endif
        return gcdMemoryWarningPublisher.subject
            .eraseToAnyPublisher()
            .merge(with: systemNotification)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

private final class GCDMemoryWarningPublisher {
    let subject = PassthroughSubject<Void, Never>()
    private let source: DispatchSourceMemoryPressure
    
    init() {
        source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let level = source.data
            if level.contains(.warning) || level.contains(.critical) {
                subject.send()
            }
        }
        source.resume()
    }
}
