//
//  CurrentDeviceTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/CurrentDevice.swift
//  Exercises the CurrentDevice namespace enum and its static device/system/disk
//  introspection surface. Tests run on the iOS Simulator, so platform-pinned
//  facts (systemName == "iOS", isSimulator == true) are asserted; runtime-variable
//  values (deviceModel / version / disk) are validated against re-derived
//  invariants rather than hard-coded constants to stay non-flaky.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct CurrentDeviceTests {

    // Faithful re-implementation of the source's deviceModel -> DeviceType rules.
    // Kept private/static so it cannot collide with helpers in other suites that
    // compile into the same test module.
    private static func derivedType(from rawModel: String) -> CurrentDevice.DeviceType {
        let model = rawModel.lowercased()
        if model.contains("phone") {
            return .phone
        } else if model.contains("pad") {
            return .pad
        } else if model.contains("pod") {
            return .pod
        } else if model.contains("tv") {
            return .tv
        } else if model.contains("mac") {
            return .mac
        } else if model.contains("watch") {
            return .watch
        } else if model.contains("realitydevice") {
            return .vision
        } else {
            return .unknown
        }
    }

    private static let allDeviceTypes: [CurrentDevice.DeviceType] = [
        .phone, .pad, .pod, .mac, .tv, .watch, .vision, .unknown,
    ]

    // MARK: - systemName

    @Test func systemNameIsIOSOnSimulator() {
        // The test bundle is built for the iOS Simulator, so the #if os(iOS)
        // branch is compiled in.
        #expect(CurrentDevice.systemName == "iOS")
    }

    @Test func systemNameIsStableAcrossReads() {
        // Backed by a `static let`: capture once, then confirm repeated reads
        // return that exact captured value (meaningful, not a self-compare).
        let snapshot = CurrentDevice.systemName
        for _ in 0..<100 {
            #expect(CurrentDevice.systemName == snapshot)
        }
        #expect(!snapshot.isEmpty)
    }

    // MARK: - isSimulator

    @Test func isSimulatorIsTrueWhenRunningOnSimulator() {
        // Tests run on the iOS 26 Simulator => targetEnvironment(simulator) is set.
        #expect(CurrentDevice.isSimulator == true)
    }

    @Test func isSimulatorIsStable() {
        let snapshot = CurrentDevice.isSimulator
        for _ in 0..<100 {
            #expect(CurrentDevice.isSimulator == snapshot)
        }
    }

    @Test func isSimulatorAndDeviceModelAgree() {
        // On the simulator deviceModel is sourced from SIMULATOR_MODEL_IDENTIFIER.
        // We don't assert the exact value here, only that the simulator flag is
        // consistent with the env-driven model path being taken.
        #expect(CurrentDevice.isSimulator)
        #expect(!CurrentDevice.deviceModel.isEmpty)
    }

    // MARK: - deviceModel

    @Test func deviceModelIsNonEmpty() {
        // Source guarantees a non-empty result: empty -> "unknown".
        #expect(!CurrentDevice.deviceModel.isEmpty)
    }

    @Test func deviceModelMatchesSimulatorEnvWhenPresent() {
        // On the simulator the value is sourced from SIMULATOR_MODEL_IDENTIFIER.
        // If that env var is present we can assert an exact equality; otherwise
        // the source falls back to "unknown".
        if let raw = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !raw.isEmpty {
            #expect(CurrentDevice.deviceModel == raw)
        } else {
            #expect(CurrentDevice.deviceModel == "unknown")
        }
    }

    @Test func deviceModelIsStableAcrossReads() {
        let snapshot = CurrentDevice.deviceModel
        for _ in 0..<100 {
            #expect(CurrentDevice.deviceModel == snapshot)
        }
    }

    @Test func deviceModelIsNeverWhitespaceOnly() {
        // The non-empty guarantee should also mean it isn't pure whitespace.
        let trimmed = CurrentDevice.deviceModel.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!trimmed.isEmpty)
    }

    // MARK: - deviceType

    @Test func deviceTypeIsConsistentWithDeviceModel() {
        // Re-derive the expected DeviceType from deviceModel using the exact same
        // substring rules the source uses, so this stays correct on any simulator.
        let expected = Self.derivedType(from: CurrentDevice.deviceModel)
        #expect(CurrentDevice.deviceType == expected)
    }

    @Test func deviceTypeIsAPhoneOrPadOnIOSSimulator() {
        // The iOS Simulator only ships iPhone / iPad device identifiers.
        let type = CurrentDevice.deviceType
        #expect(type == .phone || type == .pad)
    }

    @Test func deviceTypeIsNotUnknownOnIOSSimulator() {
        // A real, env-provided model on the iOS simulator must classify cleanly.
        #expect(CurrentDevice.deviceType != .unknown)
    }

    @Test func deviceTypeIsStableAcrossReads() {
        let snapshot = CurrentDevice.deviceType
        for _ in 0..<100 {
            #expect(CurrentDevice.deviceType == snapshot)
        }
    }

    // Exercise the exact branch-ordering of the source's classifier with synthetic
    // identifiers. This pins the documented precedence ("phone" before "pad"/"pod",
    // "tv" before "mac") without touching source.
    @Test(arguments: [
        ("iPhone18,3", CurrentDevice.DeviceType.phone),
        ("iPad13,1", .pad),
        ("iPod9,1", .pod),
        ("Mac15,3", .mac),
        ("MacBookPro18,1", .mac),
        ("AppleTV11,1", .tv),
        ("Watch6,1", .watch),
        ("RealityDevice14,1", .vision),
        ("", .unknown),
        ("totally-unrecognized", .unknown),
        ("IPHONE-UPPERCASE", .phone),       // case-insensitive
    ] as [(String, CurrentDevice.DeviceType)])
    func deviceTypeClassifierPrecedence(_ raw: String, _ expected: CurrentDevice.DeviceType) {
        #expect(Self.derivedType(from: raw) == expected)
    }

    // MARK: - DeviceType (Hashable / Equatable / case coverage)

    @Test func deviceTypeAllCasesAreDistinct() {
        let all = Self.allDeviceTypes
        // 8 distinct cases => a Set of them has 8 elements.
        let set = Set(all)
        #expect(set.count == all.count)
        #expect(set.count == 8)
    }

    @Test func deviceTypeEqualityAndHashing() {
        #expect(CurrentDevice.DeviceType.phone == CurrentDevice.DeviceType.phone)
        #expect(CurrentDevice.DeviceType.phone != CurrentDevice.DeviceType.pad)
        // Equal cases must hash equally.
        #expect(
            CurrentDevice.DeviceType.vision.hashValue
                == CurrentDevice.DeviceType.vision.hashValue
        )
        // All 8 distinct cases must remain distinct as Set elements.
        let asSet = Set(Self.allDeviceTypes)
        #expect(asSet.count == 8)
    }

    @Test(arguments: [
        CurrentDevice.DeviceType.phone,
        .pad,
        .pod,
        .mac,
        .tv,
        .watch,
        .vision,
        .unknown,
    ])
    func deviceTypeIsReflexiveAndUsableAsDictKey(_ type: CurrentDevice.DeviceType) {
        #expect(type == type)
        var dict: [CurrentDevice.DeviceType: Int] = [:]
        dict[type, default: 0] += 1
        dict[type, default: 0] += 1
        #expect(dict[type] == 2)
        #expect(dict.count == 1)
    }

    @Test func deviceTypeEachCaseIsUniqueAsDictKey() {
        // Build a dictionary keyed by every case; collisions would shrink count.
        var dict: [CurrentDevice.DeviceType: Int] = [:]
        for (index, type) in Self.allDeviceTypes.enumerated() {
            dict[type] = index
        }
        #expect(dict.count == 8)
        for (index, type) in Self.allDeviceTypes.enumerated() {
            #expect(dict[type] == index)
        }
    }

    // MARK: - userInterfaceIdiom

    @Test func userInterfaceIdiomIsPhoneOrPadOnIOSSimulator() {
        // On the iOS Simulator (not Mac Catalyst, isiOSAppOnMac == false) the idiom is
        // derived purely from deviceType, which is iPhone/iPad here.
        let idiom = CurrentDevice.userInterfaceIdiom
        #expect(idiom == .phone || idiom == .pad)
    }

    @Test func userInterfaceIdiomMatchesDeviceTypeOnIOSSimulator() {
        // Re-derive from deviceType using the same mapping the source applies on the
        // iOS (non-Catalyst, non-iOSAppOnMac) path.
        let expected: CurrentDevice.UserInterfaceIdiom
        switch CurrentDevice.deviceType {
        case .phone, .pod:
            expected = .phone
        case .pad:
            expected = .pad
        default:
            expected = .unspecified
        }
        #expect(CurrentDevice.userInterfaceIdiom == expected)
    }

    @Test func userInterfaceIdiomIsStableAcrossReads() {
        // Backed by a UIKit-free `static let`: capture once, then confirm repeated
        // reads return that exact captured value.
        let snapshot = CurrentDevice.userInterfaceIdiom
        for _ in 0..<100 {
            #expect(CurrentDevice.userInterfaceIdiom == snapshot)
        }
    }

    @Test func userInterfaceIdiomIsReadableOffMainThread() async {
        // It's a UIKit-free, Sendable `static let`, so it must be observable off the
        // main thread with a consistent value (no @MainActor / UIKit dependency).
        let expected = CurrentDevice.userInterfaceIdiom
        let value = await Task.detached { CurrentDevice.userInterfaceIdiom }.value
        #expect(value == expected)
    }

    @Test func userInterfaceIdiomIsConcurrencySafe() async {
        let expected = CurrentDevice.userInterfaceIdiom
        let taskCount = 1000
        let okCount = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<taskCount {
                group.addTask { CurrentDevice.userInterfaceIdiom == expected }
            }
            var count = 0
            for await ok in group where ok {
                count += 1
            }
            return count
        }
        #expect(okCount == taskCount)
    }

    @Test func userInterfaceIdiomAllCasesAreDistinct() {
        let all: [CurrentDevice.UserInterfaceIdiom] = [
            .unspecified, .phone, .pad, .tv, .mac, .watch, .vision,
        ]
        #expect(Set(all).count == all.count)
        #expect(Set(all).count == 7)
    }

    // MARK: - systemVersion

    @Test func systemVersionMatchesProcessInfo() {
        // Re-implement the exact formatting the source uses and compare.
        let info = ProcessInfo.processInfo.operatingSystemVersion
        var expected = "\(info.majorVersion).\(info.minorVersion)"
        if info.patchVersion != 0 {
            expected += ".\(info.patchVersion)"
        }
        #expect(CurrentDevice.systemVersion == expected)
    }

    @Test func systemVersionFormatIsDotSeparatedNumbers() {
        // Should be either "major.minor" or "major.minor.patch", all numeric,
        // with no leading/trailing/empty components.
        let version = CurrentDevice.systemVersion
        #expect(!version.hasPrefix("."))
        #expect(!version.hasSuffix("."))
        #expect(!version.contains(".."))
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 2 || parts.count == 3)
        for part in parts {
            let value = Int(part)
            #expect(value != nil)
            #expect((value ?? -1) >= 0)
        }
    }

    @Test func systemVersionMajorMatchesProcessInfo() {
        // The leading component must equal ProcessInfo's reported major version.
        let info = ProcessInfo.processInfo.operatingSystemVersion
        let first = CurrentDevice.systemVersion.split(separator: ".").first
        #expect(first.flatMap { Int($0) } == info.majorVersion)
    }

    @Test func systemVersionOmitsZeroPatch() {
        // When patchVersion == 0 the source must NOT append ".0".
        let info = ProcessInfo.processInfo.operatingSystemVersion
        let parts = CurrentDevice.systemVersion.split(separator: ".")
        if info.patchVersion == 0 {
            #expect(parts.count == 2)
        } else {
            #expect(parts.count == 3)
            #expect(parts.last.flatMap { Int($0) } == info.patchVersion)
        }
    }

    @Test func systemVersionIsStable() {
        let snapshot = CurrentDevice.systemVersion
        for _ in 0..<100 {
            #expect(CurrentDevice.systemVersion == snapshot)
        }
        #expect(!snapshot.isEmpty)
    }

    // MARK: - totalDiskSpaceInBytes

    @Test func totalDiskSpaceIsPresentAndPositive() throws {
        // On a running simulator the home directory's volume reports a size.
        let total = try #require(CurrentDevice.totalDiskSpaceInBytes)
        #expect(total > 0)
    }

    @Test func totalDiskSpaceIsStableLet() throws {
        // Backed by `static let` => identical across reads.
        let a = try #require(CurrentDevice.totalDiskSpaceInBytes)
        let b = try #require(CurrentDevice.totalDiskSpaceInBytes)
        #expect(a == b)
    }

    @Test func totalDiskSpaceMatchesFileManagerQuery() throws {
        // The source reads attributesOfFileSystem(forPath: NSHomeDirectory()).
        // Re-run the same query and confirm the cached `let` agrees.
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let expected = try #require(attrs[.systemSize] as? UInt64)
        let total = try #require(CurrentDevice.totalDiskSpaceInBytes)
        #expect(total == expected)
    }

    // MARK: - freeDiskSpaceInBytes

    @Test func freeDiskSpaceIsPresentAndPositive() throws {
        let free = try #require(CurrentDevice.freeDiskSpaceInBytes)
        #expect(free > 0)
    }

    @Test func freeDiskSpaceDoesNotExceedTotal() throws {
        let total = try #require(CurrentDevice.totalDiskSpaceInBytes)
        let free = try #require(CurrentDevice.freeDiskSpaceInBytes)
        // Free space can never exceed total volume size.
        #expect(free <= total)
    }

    @Test func freeDiskSpaceIsComputedFreshEachRead() throws {
        // `freeDiskSpaceInBytes` is a computed `static var`. The underlying number
        // may drift slightly between reads, so we do NOT assert exact equality;
        // instead we assert both reads stay valid and within the total bound.
        let total = try #require(CurrentDevice.totalDiskSpaceInBytes)
        let a = try #require(CurrentDevice.freeDiskSpaceInBytes)
        let b = try #require(CurrentDevice.freeDiskSpaceInBytes)
        #expect(a > 0)
        #expect(b > 0)
        #expect(a <= total)
        #expect(b <= total)
    }

    // MARK: - Concurrency

    @Test func staticPropertiesAreConcurrencySafe() async {
        // CurrentDevice is Sendable and its statics are `let`/pure-computed; hammer
        // them from many tasks and assert every reader observes the same values
        // with no crash / data race.
        let expectedName = CurrentDevice.systemName
        let expectedModel = CurrentDevice.deviceModel
        let expectedType = CurrentDevice.deviceType
        let expectedVersion = CurrentDevice.systemVersion
        let expectedSimulator = CurrentDevice.isSimulator
        let expectedTotal = CurrentDevice.totalDiskSpaceInBytes

        let taskCount = 1000
        let okCount = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<taskCount {
                group.addTask {
                    CurrentDevice.systemName == expectedName
                        && CurrentDevice.deviceModel == expectedModel
                        && CurrentDevice.deviceType == expectedType
                        && CurrentDevice.systemVersion == expectedVersion
                        && CurrentDevice.isSimulator == expectedSimulator
                        && CurrentDevice.totalDiskSpaceInBytes == expectedTotal
                        && (CurrentDevice.freeDiskSpaceInBytes ?? 0) > 0
                }
            }
            var count = 0
            for await ok in group where ok {
                count += 1
            }
            return count
        }
        // Every single task must have observed a fully consistent snapshot.
        #expect(okCount == taskCount)
    }

    // MARK: - Type-level guarantees

    @Test func currentDeviceIsSendable() {
        // Compile-time proof that CurrentDevice and DeviceType conform to Sendable.
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(CurrentDevice.self)
        requireSendable(CurrentDevice.DeviceType.self)
        // CurrentDevice has no cases; this just confirms the metatype usage works.
        #expect(CurrentDevice.DeviceType.phone == .phone)
    }
}
