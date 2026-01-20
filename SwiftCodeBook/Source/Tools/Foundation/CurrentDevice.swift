//
//  CurrentDevice.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/1/19.
//

import Foundation

@frozen public enum CurrentDevice: Sendable {
    public static func systemName(treatIPadOSAsIOS: Bool = false) -> String {
        #if os(watchOS)
        return "watchOS"

        #elseif os(tvOS)
        return "tvOS"

        #elseif os(visionOS)
        return "visionOS"

        #elseif os(macOS)
        return "macOS"

        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        return "macOS"
        #else
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return "macOS"
        }

        if deviceModel.lowercased().contains("ipad") {
            return treatIPadOSAsIOS ? "iOS" : "iPadOS"
        } else {
            return "iOS"
        }
        #endif

        #else
        return "unknown"
        #endif
    }
    
    public static var systemVersion: String {
        let info = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(info.majorVersion).\(info.minorVersion)"
        return info.patchVersion == 0 ? version : version + ".\(info.patchVersion)"
    }
    
    public static var isSimulator: Bool {
#if targetEnvironment(simulator)
        true
#else
        false
#endif
    }
    
    // https://www.hubweb.cn
    // https://theapplewiki.com/wiki/Main_Page
    public static var deviceModel: String {
        if isSimulator {
            return String(format: "%s", getenv("SIMULATOR_MODEL_IDENTIFIER"))
        } else {
            var info = utsname()
            uname(&info)
            let chars = (Mirror(reflecting: info.machine).children.map(\.value) as? [CChar]) ?? []
            return String(cString: chars)
        }
    }
    
    public static var is64BitDevice: Bool {
        Int.bitWidth == 64
    }
    
    public static var totalDiskSpaceInByte: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemSize] as? UInt64
    }
    
    public static var freeDiskSpaceInByte: UInt64? {
        (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()))?[.systemFreeSize] as? UInt64
    }
}
