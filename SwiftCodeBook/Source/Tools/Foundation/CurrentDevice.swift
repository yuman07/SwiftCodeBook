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
#if canImport(WatchKit)
import WatchKit
#endif

@frozen public enum CurrentDevice: Sendable {}

public extension CurrentDevice {
    @MainActor
    static let systemName = {
#if os(macOS)
        "macOS"
#elseif os(iOS) || os(tvOS) || os(visionOS)
        UIDevice.current.systemName
#elseif os(watchOS)
        WKInterfaceDevice.current().systemName
#else
        "unknown"
#endif
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
        if isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
            return String(cString: chars, encoding: .utf8) ?? "unknown"
        }
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
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64
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
