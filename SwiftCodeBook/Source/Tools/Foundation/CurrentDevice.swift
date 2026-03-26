//
//  CurrentDevice.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

@frozen public enum CurrentDevice: Sendable {}

public extension CurrentDevice {
    static let systemName = {
#if os(iOS)
        "iOS"
#elseif os(macOS)
        "macOS"
#elseif os(tvOS)
        "tvOS"
#elseif os(visionOS)
        "visionOS"
#elseif os(watchOS)
        "watchOS"
#else
        "unknown"
#endif
    }()
    
    @frozen enum DeviceType: Sendable, Hashable {
        case iPhone
        case iPad
        case iPod
        case mac
        case tv
        case watch
        case vision
        case unknown
    }
    
    static let deviceType: DeviceType = {
        let deviceModel = Self.deviceModel.lowercased()
        if deviceModel.contains("iphone") {
            return .iPhone
        } else if deviceModel.contains("ipad") {
            return .iPad
        } else if deviceModel.contains("ipod") {
            return .iPod
        } else if deviceModel.contains("mac") {
            return .mac
        } else if deviceModel.contains("tv") {
            return .tv
        } else if deviceModel.contains("watch") {
            return .watch
        } else if deviceModel.contains("realitydevice") {
            return .vision
        } else {
            return .unknown
        }
    }()
    
    static let systemVersion = {
        let info = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(info.majorVersion).\(info.minorVersion)"
        return info.patchVersion == 0 ? version : version + ".\(info.patchVersion)"
    }()
    
    static let isSimulator = {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }()
    
    // https://www.hubweb.cn
    // https://theapplewiki.com/wiki/Main_Page
    static let deviceModel = {
        var model = ""
        if isSimulator {
            if let env = getenv("SIMULATOR_MODEL_IDENTIFIER") {
                model = String(cString: env)
            }
        } else {
            var info = utsname()
            uname(&info)
            model = withUnsafePointer(to: info.machine) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                    String(cString: $0)
                }
            }
        }
        return model.isEmpty ? "unknown" : model
    }()
    
    static let is64BitDevice = {
        Int.bitWidth == 64
    }()
}

public extension CurrentDevice {
    static let totalDiskSpaceInByte = {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64
    }()
    
    static var freeDiskSpaceInByte: UInt64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.flatMap { $0 >= 0 ? UInt64($0) : nil }
    }
}

public extension CurrentDevice {
    @frozen enum HapticFeedbackStyle: Sendable {
        case light
        case medium
        case heavy
        case soft
        case rigid
#if os(iOS)
        public var uikitFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: .light
            case .medium: .medium
            case .heavy: .heavy
            case .soft: .soft
            case .rigid: .rigid
            }
        }
#endif
    }
    
    static func triggerHapticFeedbackIfCould(_ style: CurrentDevice.HapticFeedbackStyle) {
#if os(iOS)
        DispatchQueue.dispatchToMainIfNeeded {
            let generator = UIImpactFeedbackGenerator(style: style.uikitFeedbackStyle)
            generator.prepare()
            generator.impactOccurred()
        }
#endif
    }
}
