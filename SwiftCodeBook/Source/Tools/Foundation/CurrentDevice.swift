//
//  CurrentDevice.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Darwin
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
    static let deviceModel = {
        let selector = {
#if os(macOS) || targetEnvironment(macCatalyst)
            return "hw.model"
#elseif os(iOS)
            if ProcessInfo.processInfo.isiOSAppOnMac {
                return "hw.model"
            } else {
                return "hw.machine"
            }
#else
            return "hw.machine"
#endif
        }()
        
        var model = ""
#if targetEnvironment(simulator)
        if let env = getenv("SIMULATOR_MODEL_IDENTIFIER") {
            model = String(cString: env)
        }
#else
        var size = 0
        if sysctlbyname(selector, nil, &size, nil, 0) == 0 && size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            if sysctlbyname(selector, &buffer, &size, nil, 0) == 0 {
                model = String(cString: buffer, encoding: .utf8) ?? ""
            }
        }
#endif
        return model.isEmpty ? "unknown" : model
    }()
    
    static let is64BitDevice = {
        Int.bitWidth == 64
    }()
}

public extension CurrentDevice {
    static let totalDiskSpaceInBytes = {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64
    }()
    
    static var freeDiskSpaceInBytes: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64
    }
}
