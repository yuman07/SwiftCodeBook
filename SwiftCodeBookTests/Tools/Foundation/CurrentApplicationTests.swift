//
//  CurrentApplicationTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/CurrentApplication.swift
//
//  Notes on the test environment:
//  - Tests run on the iOS Simulator with `SwiftCodeBook.app` as TEST_HOST, so
//    `Bundle.main` resolves to the host app bundle (the framework's own bundle
//    is NOT main). All `Bundle.main`-derived statics therefore reflect the host
//    app's generated Info.plist.
//  - On iOS the `os(iOS)` / `canImport(UIKit)` compilation branches are active:
//      * `keyWindow`        -> @MainActor UIWindow?
//      * `appIcon`          -> non-isolated UIImage?
//      * `memoryWarningPublisher` merges in UIApplication.didReceiveMemoryWarningNotification
//

import Combine
import Foundation
import Testing
import UIKit
@testable import SwiftCodeBook

@Suite struct CurrentApplicationTests {

    // MARK: - appVersion

    @Test func appVersionMatchesBundleShortVersionString() {
        let expected = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        #expect(CurrentApplication.appVersion == expected)
    }

    @Test func appVersionIsStableAcrossReads() {
        // Backed by a lazily-evaluated `static let`: must be identical every read.
        let a = CurrentApplication.appVersion
        let b = CurrentApplication.appVersion
        #expect(a == b)
    }

    @Test func appVersionIsNonEmptyWhenPresent() {
        if let v = CurrentApplication.appVersion {
            #expect(!v.isEmpty)
        }
    }

    // MARK: - appBuildNumber

    @Test func appBuildNumberMatchesParsedBundleVersion() {
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let expected = raw.flatMap { Int($0) }
        #expect(CurrentApplication.appBuildNumber == expected)
    }

    @Test func appBuildNumberIsStableAcrossReads() {
        #expect(CurrentApplication.appBuildNumber == CurrentApplication.appBuildNumber)
    }

    @Test func appBuildNumberIsNonNegativeWhenPresent() {
        // CFBundleVersion is conventionally a positive integer string; if it parsed
        // at all it should be a sane (non-negative) value for this project.
        if let build = CurrentApplication.appBuildNumber {
            #expect(build >= 0)
        }
    }

    @Test func appBuildNumberIsNilWhenRawVersionIsNonNumeric() {
        // Cross-check the source's `Int($0)` parse contract against the raw plist
        // value: the static must be nil exactly when the raw string fails to parse.
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let raw, Int(raw) == nil {
            #expect(CurrentApplication.appBuildNumber == nil)
        } else if raw == nil {
            #expect(CurrentApplication.appBuildNumber == nil)
        } else {
            #expect(CurrentApplication.appBuildNumber != nil)
        }
    }

    // MARK: - appBundleIdentifier

    @Test func appBundleIdentifierMatchesInfoDictionary() {
        let expected = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
        #expect(CurrentApplication.appBundleIdentifier == expected)
    }

    @Test func appBundleIdentifierMatchesBundleProperty() {
        // CFBundleIdentifier in infoDictionary should agree with Bundle.bundleIdentifier.
        #expect(CurrentApplication.appBundleIdentifier == Bundle.main.bundleIdentifier)
    }

    @Test func appBundleIdentifierIsStableAcrossReads() {
        #expect(CurrentApplication.appBundleIdentifier == CurrentApplication.appBundleIdentifier)
    }

    @Test func appBundleIdentifierIsNonEmptyWhenPresent() {
        if let id = CurrentApplication.appBundleIdentifier {
            #expect(!id.isEmpty)
        }
    }

    // MARK: - appDisplayName

    @Test func appDisplayNameFollowsFallbackLogic() {
        // Source: CFBundleDisplayName ?? CFBundleName.
        let display = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        let name = Bundle.main.infoDictionary?["CFBundleName"] as? String
        let expected = display ?? name
        #expect(CurrentApplication.appDisplayName == expected)
    }

    @Test func appDisplayNamePrefersDisplayNameOverName() {
        // When CFBundleDisplayName exists it must win over CFBundleName; otherwise
        // the value must coincide with CFBundleName (or nil when both are absent).
        let display = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        let name = Bundle.main.infoDictionary?["CFBundleName"] as? String
        if let display {
            #expect(CurrentApplication.appDisplayName == display)
        } else {
            #expect(CurrentApplication.appDisplayName == name)
        }
    }

    @Test func appDisplayNameIsStableAcrossReads() {
        #expect(CurrentApplication.appDisplayName == CurrentApplication.appDisplayName)
    }

    @Test func appDisplayNameIsNonEmptyWhenPresent() {
        if let n = CurrentApplication.appDisplayName {
            #expect(!n.isEmpty)
        }
    }

    // MARK: - usedMemoryInBytes

    @Test func usedMemoryInBytesIsPositive() throws {
        // task_info(TASK_VM_INFO) succeeds for a live process; phys_footprint > 0.
        let used = try #require(CurrentApplication.usedMemoryInBytes)
        #expect(used > 0)
    }

    @Test func usedMemoryInBytesIsSane() throws {
        // Footprint should be well below an absurd ceiling (1 TB) for a unit-test
        // process — guards against a bogus reinterpretation of the struct bytes.
        let used = try #require(CurrentApplication.usedMemoryInBytes)
        #expect(used < 1_000_000_000_000)
    }

    @Test func usedMemoryInBytesIsRepeatable() throws {
        // Each access recomputes from a fresh task_info call; both should succeed
        // and stay within the same order of magnitude across two adjacent reads.
        let first = try #require(CurrentApplication.usedMemoryInBytes)
        let second = try #require(CurrentApplication.usedMemoryInBytes)
        let lo = min(first, second)
        let hi = max(first, second)
        // Allow generous drift but reject a swing of >100x which would signal a bug.
        #expect(hi <= lo * 100 + 1_000_000)
    }

    @Test func usedMemoryInBytesIsThreadSafeUnderConcurrency() async throws {
        // The getter only reads local stack storage + a mach syscall, so concurrent
        // access must never crash and must always yield a positive value.
        let results: [UInt64] = await withTaskGroup(of: UInt64?.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    CurrentApplication.usedMemoryInBytes
                }
            }
            var collected: [UInt64] = []
            for await value in group {
                if let value { collected.append(value) }
            }
            return collected
        }
        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 > 0 })
        // Under no artificial pressure all concurrent reads should land in the same
        // ballpark (no >100x spread), confirming the syscall is not racing on the
        // shared `count` argument in a way that corrupts results.
        if let lo = results.min(), let hi = results.max() {
            #expect(hi <= lo * 100 + 1_000_000)
        }
    }

    // MARK: - keyWindow (@MainActor on iOS)

    @MainActor
    @Test func keyWindowDoesNotCrashAndTypeIsCorrect() {
        // No active UIWindowScene with a key window is guaranteed in a unit-test
        // host, so the value may legitimately be nil. We only assert it is safely
        // accessible and, if present, is a real UIWindow.
        let window: UIWindow? = CurrentApplication.keyWindow
        if let window {
            #expect(window.isKind(of: UIWindow.self))
        } else {
            #expect(window == nil)
        }
    }

    @MainActor
    @Test func keyWindowNilnessIsStableAcrossReads() {
        // Two consecutive reads on the main actor (no scene mutation in between)
        // must not crash and must agree on nil-ness, and when both are non-nil they
        // must resolve to the *same* window instance (it is derived deterministically
        // from the connected scenes).
        let first = CurrentApplication.keyWindow
        let second = CurrentApplication.keyWindow
        #expect((first == nil) == (second == nil))
        if let first, let second {
            #expect(first === second)
        }
    }

    // MARK: - appIcon (non-isolated on iOS)

    @Test func appIconAccessDoesNotCrash() {
        // The host app's generated Info.plist does not declare CFBundleIcons /
        // CFBundlePrimaryIcon / CFBundleIconFiles, so this resolves to nil. We
        // assert it is at least safely accessible and, if non-nil, a UIImage.
        let icon: UIImage? = CurrentApplication.appIcon
        if let icon {
            #expect(icon.isKind(of: UIImage.self))
        } else {
            #expect(icon == nil)
        }
    }

    @Test func appIconMatchesBundleIconDeclaration() {
        // Mirror the source's lookup chain: appIcon is non-nil only when the full
        // CFBundleIcons -> CFBundlePrimaryIcon -> CFBundleIconFiles chain resolves
        // AND UIImage(named:) finds the last-listed asset.
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [AnyHashable: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [AnyHashable: Any]
        let files = primary?["CFBundleIconFiles"] as? [String]
        if let last = files?.last, UIImage(named: last) != nil {
            #expect(CurrentApplication.appIcon != nil)
        } else {
            #expect(CurrentApplication.appIcon == nil)
        }
    }

    @Test func appIconIsRepeatable() {
        // Pure read derived from Bundle.main; repeated calls agree on nil-ness.
        let a = CurrentApplication.appIcon
        let b = CurrentApplication.appIcon
        #expect((a == nil) == (b == nil))
    }

    // MARK: - memoryWarningPublisher

    @Test func memoryWarningPublisherDoesNotEmitSpuriously() async {
        // With no memory warning posted, the publisher should remain silent.
        // We confirm zero deliveries within a bounded subscription window.
        await confirmation("no spurious memory warning", expectedCount: 0) { confirm in
            let cancellable = CurrentApplication.memoryWarningPublisher
                .sink { _ in confirm() }

            // Drive the run loop / main queue briefly without sleeping by hopping
            // to the main actor a few times so any queued delivery would surface.
            for _ in 0..<5 {
                await MainActor.run { _ = CurrentApplication.usedMemoryInBytes }
            }
            cancellable.cancel()
        }
    }

    @Test func memoryWarningPublisherDeliversOnSystemMemoryWarningNotification() async {
        // The publisher merges in UIApplication.didReceiveMemoryWarningNotification.
        // Posting that notification must produce exactly one Void event, delivered
        // on the main queue (publisher uses `.receive(on: DispatchQueue.main)`).
        await confirmation("memory warning forwarded", expectedCount: 1) { confirm in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let box = CancellableBox()
                box.cancellable = CurrentApplication.memoryWarningPublisher
                    .first()
                    .sink { _ in
                        #expect(Thread.isMainThread)
                        confirm()
                        continuation.resume()
                    }

                // Post the notification on the main thread to mirror UIKit behavior.
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: UIApplication.didReceiveMemoryWarningNotification,
                        object: nil
                    )
                }
            }
        }
    }

    @Test func memoryWarningPublisherSupportsMultipleIndependentSubscribers() async {
        // A fresh publisher chain is built per access; two concurrent subscribers
        // must each receive the single posted notification (NotificationCenter +
        // PassthroughSubject both multicast).
        await confirmation("both subscribers notified", expectedCount: 2) { confirm in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let box = CancellableBox()
                let counter = Counter()

                let handle: @Sendable () -> Void = {
                    confirm()
                    if counter.increment() == 2 {
                        continuation.resume()
                    }
                }

                box.cancellables.append(
                    CurrentApplication.memoryWarningPublisher.first().sink { _ in handle() }
                )
                box.cancellables.append(
                    CurrentApplication.memoryWarningPublisher.first().sink { _ in handle() }
                )

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: UIApplication.didReceiveMemoryWarningNotification,
                        object: nil
                    )
                }
            }
        }
    }

    @Test func memoryWarningPublisherCancellationStopsDelivery() async {
        // After a subscriber cancels, a subsequently posted notification must NOT
        // reach it. Confirm exactly one delivery: the live subscriber fires, the
        // cancelled one does not.
        await confirmation("only the live subscriber fires", expectedCount: 1) { confirm in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let box = CancellableBox()

                // Subscriber A: cancelled before any notification is posted.
                let cancelledFirst = CurrentApplication.memoryWarningPublisher
                    .sink { _ in
                        Issue.record("cancelled subscriber must not receive events")
                    }
                cancelledFirst.cancel()

                // Subscriber B: stays alive and should receive the single event.
                box.cancellable = CurrentApplication.memoryWarningPublisher
                    .first()
                    .sink { _ in
                        confirm()
                        continuation.resume()
                    }

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: UIApplication.didReceiveMemoryWarningNotification,
                        object: nil
                    )
                }
            }
        }
    }

    @Test func memoryWarningPublisherSubscribeAndCancelDoesNotCrash() {
        // Obtaining the accessor and immediately subscribing/cancelling must be a
        // safe no-op (a new erased publisher chain is constructed per call). This
        // replaces a trivially-true assertion with an exercise of the real chain.
        let p1: AnyPublisher<Void, Never> = CurrentApplication.memoryWarningPublisher
        let p2: AnyPublisher<Void, Never> = CurrentApplication.memoryWarningPublisher
        let c1 = p1.sink { _ in }
        let c2 = p2.sink { _ in }
        c1.cancel()
        c2.cancel()
        // If we got here the chain built and tore down without trapping.
        #expect(Bool(true))
    }

    // MARK: - Sendable / enum shape

    @Test func currentApplicationIsAnUninhabitedEnum() {
        // `@frozen public enum CurrentApplication: Sendable {}` has no cases, so
        // it can only ever be used as a namespace. An uninhabited enum occupies no
        // storage.
        #expect(MemoryLayout<CurrentApplication>.size == 0)
        #expect(MemoryLayout<CurrentApplication>.stride == 1)
    }

    @Test func staticsReadableFromConcurrentContext() async {
        // Exercise the Sendable namespace's lazily-initialized value statics from
        // many child tasks. The `static let` values must be identical across every
        // task (no torn lazy init), and the live `usedMemoryInBytes` must always be
        // present and positive.
        struct Snapshot: Sendable, Equatable {
            let version: String?
            let build: Int?
            let bundleID: String?
            let display: String?
            let memoryPresentAndPositive: Bool
        }

        let snapshots: [Snapshot] = await withTaskGroup(of: Snapshot.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    Snapshot(
                        version: CurrentApplication.appVersion,
                        build: CurrentApplication.appBuildNumber,
                        bundleID: CurrentApplication.appBundleIdentifier,
                        display: CurrentApplication.appDisplayName,
                        memoryPresentAndPositive: (CurrentApplication.usedMemoryInBytes ?? 0) > 0
                    )
                }
            }
            var collected: [Snapshot] = []
            for await snapshot in group {
                collected.append(snapshot)
            }
            return collected
        }

        #expect(snapshots.count == 200)
        // All `static let`-backed fields must be identical across every task.
        let expected = Snapshot(
            version: CurrentApplication.appVersion,
            build: CurrentApplication.appBuildNumber,
            bundleID: CurrentApplication.appBundleIdentifier,
            display: CurrentApplication.appDisplayName,
            memoryPresentAndPositive: true
        )
        #expect(snapshots.allSatisfy { $0.version == expected.version })
        #expect(snapshots.allSatisfy { $0.build == expected.build })
        #expect(snapshots.allSatisfy { $0.bundleID == expected.bundleID })
        #expect(snapshots.allSatisfy { $0.display == expected.display })
        #expect(snapshots.allSatisfy { $0.memoryPresentAndPositive })
    }

    // MARK: - Test helpers

    /// Holds Combine cancellables alive across a continuation without tripping
    /// Sendable capture rules; only mutated/read on the main queue in these tests.
    private final class CancellableBox: @unchecked Sendable {
        var cancellable: AnyCancellable?
        var cancellables: [AnyCancellable] = []
    }

    /// Thread-safe counter used to coordinate the multi-subscriber confirmation.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }
    }
}
