//
//  CurrentDevice.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Darwin
import Foundation

@frozen public enum CurrentDevice: Sendable {}

public extension CurrentDevice {
    static let systemName = {
#if os(iOS)
        "iOS"
#elseif os(tvOS)
        "tvOS"
#elseif os(macOS)
        "macOS"
#elseif os(watchOS)
        "watchOS"
#elseif os(visionOS)
        "visionOS"
#else
        "unknown"
#endif
    }()
    
    // iPod最后支持的iOS版本是15，等基本所有app的最低版本为iOS16后可删除该type
    @frozen enum DeviceType: Sendable, Hashable {
        case unknown
        case phone
        case pad
        case pod
        case tv
        case mac
        case watch
        case vision
    }
    
    static let deviceType: DeviceType = {
        let deviceModel = Self.deviceModel.lowercased()
        if deviceModel.contains("phone") {
            return .phone
        } else if deviceModel.contains("pad") {
            return .pad
        } else if deviceModel.contains("pod") {
            return .pod
        } else if deviceModel.contains("tv") {
            return .tv
        } else if deviceModel.contains("mac") {
            return .mac
        } else if deviceModel.contains("watch") {
            return .watch
        } else if deviceModel.contains("realitydevice") {
            return .vision
        } else {
            return .unknown
        }
    }()
    
    @frozen enum UserInterfaceIdiom: Sendable, Hashable {
        case unspecified
        case phone
        case pad
        case tv
        case mac
        case watch
        case vision
    }

    static let userInterfaceIdiom: UserInterfaceIdiom = {
#if targetEnvironment(macCatalyst)
        .mac
#elseif os(iOS)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            guard let families = Bundle.main.infoDictionary?["UIDeviceFamily"] as? [Int],
                  !families.isEmpty else {
                return .unspecified
            }
            return families.contains(2) ? .pad : .phone
        }
        switch Self.deviceType {
        case .phone, .pod: return .phone
        case .pad: return .pad
        default: return .unspecified
        }
#elseif os(tvOS)
        .tv
#elseif os(macOS)
        .mac
#elseif os(watchOS)
        .watch
#elseif os(visionOS)
        .vision
#else
        .unspecified
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
    static let deviceModel = {
        var model = ""
#if targetEnvironment(simulator)
        if let env = getenv("SIMULATOR_MODEL_IDENTIFIER") {
            model = String(cString: env)
        }
#else
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
}

public extension CurrentDevice {
    static let totalDiskSpaceInBytes = {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64
    }()
    
    static var freeDiskSpaceInBytes: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64
    }
}
