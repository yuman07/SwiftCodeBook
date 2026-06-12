//
//  UIInterfaceOrientationTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/UIKit/UIInterfaceOrientation.swift
//
//  Source under test: a `UIInterfaceOrientation` polyfill enum.
//
//  IMPORTANT PLATFORM NOTE:
//  The source file is wrapped in `#if os(macOS) || os(tvOS) || os(watchOS)`, so on the
//  iOS Simulator (where this test target runs) the custom enum is NOT compiled. Instead,
//  `import UIKit` brings the *real* UIKit `UIInterfaceOrientation` into scope. The polyfill
//  was deliberately authored to mirror UIKit exactly. Verified against the iOS 26.4 SDK
//  (UIOrientation.h):
//      UIInterfaceOrientationUnknown            = UIDeviceOrientationUnknown            = 0
//      UIInterfaceOrientationPortrait           = UIDeviceOrientationPortrait           = 1
//      UIInterfaceOrientationPortraitUpsideDown = UIDeviceOrientationPortraitUpsideDown = 2
//      UIInterfaceOrientationLandscapeLeft      = UIDeviceOrientationLandscapeRight     = 4
//      UIInterfaceOrientationLandscapeRight     = UIDeviceOrientationLandscapeLeft      = 3
//  The crossed landscape raw values are intentional: rotating the device left rotates the
//  content right, so UIInterfaceOrientationLandscapeLeft maps to the *device's* landscape
//  right (raw 4) and vice versa.
//
//  And per UIKit.apinotes, the free C functions are surfaced as Swift instance properties:
//      getter:UIInterfaceOrientation.isPortrait(self:)   <- UIInterfaceOrientationIsPortrait
//      getter:UIInterfaceOrientation.isLandscape(self:)  <- UIInterfaceOrientationIsLandscape
//  carrying identical semantics to the polyfill's computed properties.
//
//  Therefore every assertion below holds identically for whichever `UIInterfaceOrientation`
//  is in scope at compile time. The tests validate the contract that the polyfill promises
//  to uphold relative to UIKit: stable raw values, correct round-trips, and the
//  isPortrait/isLandscape classification for each case.
//

import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import SwiftCodeBook

@Suite struct UIInterfaceOrientationTests {

    // All five cases in one place to keep the matrix tests honest.
    private static let allCases: [UIInterfaceOrientation] = [
        .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight,
    ]

    // MARK: - Raw values

    @Test func unknownRawValueIsZero() {
        #expect(UIInterfaceOrientation.unknown.rawValue == 0)
    }

    @Test func portraitRawValueIsOne() {
        #expect(UIInterfaceOrientation.portrait.rawValue == 1)
    }

    @Test func portraitUpsideDownRawValueIsTwo() {
        #expect(UIInterfaceOrientation.portraitUpsideDown.rawValue == 2)
    }

    @Test func landscapeRightRawValueIsThree() {
        // NOTE: intentionally "crossed" raw values mirroring UIKit/UIDeviceOrientation.
        // UIInterfaceOrientationLandscapeRight == UIDeviceOrientationLandscapeLeft == 3.
        #expect(UIInterfaceOrientation.landscapeRight.rawValue == 3)
    }

    @Test func landscapeLeftRawValueIsFour() {
        // NOTE: intentionally "crossed" raw values mirroring UIKit/UIDeviceOrientation.
        // UIInterfaceOrientationLandscapeLeft == UIDeviceOrientationLandscapeRight == 4.
        #expect(UIInterfaceOrientation.landscapeLeft.rawValue == 4)
    }

    @Test func landscapeRawValuesAreCrossedRelativeToEachOther() {
        // The whole point of the "crossed" mapping: landscapeLeft's raw value is strictly
        // greater than landscapeRight's, even though "left" reads before "right".
        #expect(UIInterfaceOrientation.landscapeLeft.rawValue == 4)
        #expect(UIInterfaceOrientation.landscapeRight.rawValue == 3)
        #expect(UIInterfaceOrientation.landscapeLeft.rawValue > UIInterfaceOrientation.landscapeRight.rawValue)
    }

    @Test func allRawValuesAreDistinct() {
        let raws = Self.allCases.map(\.rawValue)
        #expect(Set(raws).count == Self.allCases.count)
        #expect(raws.count == 5)
    }

    @Test func rawValuesAreContiguousZeroThroughFour() {
        // Union of all five raw values is exactly {0,1,2,3,4}.
        #expect(Set(Self.allCases.map(\.rawValue)) == Set(0...4))
    }

    @Test func minAndMaxValidRawValuesAreUnknownAndLandscapeLeft() {
        let raws = Self.allCases.map(\.rawValue)
        // Boundary: 0 is the smallest valid raw (unknown); 4 is the largest (landscapeLeft).
        #expect(raws.min() == 0)
        #expect(raws.max() == 4)
        let lowest = UIInterfaceOrientation(rawValue: raws.min() ?? -1)
        #expect(lowest == .unknown)
        let highest = UIInterfaceOrientation(rawValue: raws.max() ?? -1)
        #expect(highest == .landscapeLeft)
    }

    // MARK: - init(rawValue:) round-trips

    @Test(arguments: [
        (0, UIInterfaceOrientation.unknown),
        (1, UIInterfaceOrientation.portrait),
        (2, UIInterfaceOrientation.portraitUpsideDown),
        (3, UIInterfaceOrientation.landscapeRight),
        (4, UIInterfaceOrientation.landscapeLeft),
    ])
    func initFromRawValueProducesExpectedCase(raw: Int, expected: UIInterfaceOrientation) throws {
        let value = try #require(UIInterfaceOrientation(rawValue: raw))
        #expect(value == expected)
        // Round-trip: rawValue of the reconstructed case matches the seed.
        #expect(value.rawValue == raw)
    }

    @Test(arguments: [
        UIInterfaceOrientation.unknown,
        .portrait,
        .portraitUpsideDown,
        .landscapeLeft,
        .landscapeRight,
    ])
    func caseRoundTripsThroughRawValue(orientation: UIInterfaceOrientation) throws {
        let rebuilt = try #require(UIInterfaceOrientation(rawValue: orientation.rawValue))
        #expect(rebuilt == orientation)
        #expect(rebuilt.rawValue == orientation.rawValue)
    }

    @Test func allCasesRoundTripExactlyOnce() throws {
        // Reconstruct every case from its raw value; the rebuilt set must equal the original
        // set, proving the rawValue <-> case mapping is a clean bijection over {0...4}.
        var rebuilt = Set<UIInterfaceOrientation>()
        for o in Self.allCases {
            let r = try #require(UIInterfaceOrientation(rawValue: o.rawValue))
            rebuilt.insert(r)
        }
        #expect(rebuilt == Set(Self.allCases))
        #expect(rebuilt.count == 5)
    }

    // MARK: - init(rawValue:) failure / boundary

    @Test(arguments: [-1, 5, 6, 100, Int.min, Int.max, 1000, -1000])
    func initFromInvalidRawValueIsNil(raw: Int) {
        #expect(UIInterfaceOrientation(rawValue: raw) == nil)
    }

    @Test func initJustOutsideValidBandIsNil() {
        // Tight off-by-one boundaries around the valid band {0...4}.
        #expect(UIInterfaceOrientation(rawValue: -1) == nil)
        #expect(UIInterfaceOrientation(rawValue: 5) == nil)
        // And the inner edges are valid.
        #expect(UIInterfaceOrientation(rawValue: 0) != nil)
        #expect(UIInterfaceOrientation(rawValue: 4) != nil)
    }

    // MARK: - isLandscape

    @Test func landscapeLeftIsLandscape() {
        #expect(UIInterfaceOrientation.landscapeLeft.isLandscape)
    }

    @Test func landscapeRightIsLandscape() {
        #expect(UIInterfaceOrientation.landscapeRight.isLandscape)
    }

    @Test func unknownIsNotLandscape() {
        #expect(!UIInterfaceOrientation.unknown.isLandscape)
    }

    @Test func portraitOrientationsAreNotLandscape() {
        #expect(!UIInterfaceOrientation.portrait.isLandscape)
        #expect(!UIInterfaceOrientation.portraitUpsideDown.isLandscape)
    }

    // MARK: - isPortrait

    @Test func portraitIsPortrait() {
        #expect(UIInterfaceOrientation.portrait.isPortrait)
    }

    @Test func portraitUpsideDownIsPortrait() {
        #expect(UIInterfaceOrientation.portraitUpsideDown.isPortrait)
    }

    @Test func unknownIsNotPortrait() {
        #expect(!UIInterfaceOrientation.unknown.isPortrait)
    }

    @Test func landscapeOrientationsAreNotPortrait() {
        #expect(!UIInterfaceOrientation.landscapeLeft.isPortrait)
        #expect(!UIInterfaceOrientation.landscapeRight.isPortrait)
    }

    // MARK: - Table-driven classification for every case

    @Test(arguments: [
        (UIInterfaceOrientation.unknown, false, false),
        (.portrait, true, false),
        (.portraitUpsideDown, true, false),
        (.landscapeLeft, false, true),
        (.landscapeRight, false, true),
    ])
    func classificationMatrix(
        orientation: UIInterfaceOrientation,
        expectPortrait: Bool,
        expectLandscape: Bool
    ) {
        #expect(orientation.isPortrait == expectPortrait)
        #expect(orientation.isLandscape == expectLandscape)
    }

    @Test func classificationMatrixCoversEveryCaseExactlyOnce() {
        // Guard against the matrix above silently dropping a case: the orientations it
        // covers must be exactly the full set of cases.
        let matrixOrientations: Set<UIInterfaceOrientation> = [
            .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight,
        ]
        #expect(matrixOrientations == Set(Self.allCases))
        #expect(matrixOrientations.count == 5)
    }

    // MARK: - Invariants across all cases

    @Test func portraitAndLandscapeAreMutuallyExclusive() {
        for o in Self.allCases {
            // No orientation can be both portrait and landscape simultaneously.
            #expect(!(o.isPortrait && o.isLandscape))
        }
    }

    @Test func onlyUnknownIsNeitherPortraitNorLandscape() {
        for o in Self.allCases {
            let neither = !o.isPortrait && !o.isLandscape
            #expect(neither == (o == .unknown))
        }
    }

    @Test func exactlyTwoCasesAreLandscapeAndTwoArePortrait() {
        // Cardinality invariant: 2 landscape, 2 portrait, 1 neither.
        let landscape = Self.allCases.filter(\.isLandscape)
        let portrait = Self.allCases.filter(\.isPortrait)
        let neither = Self.allCases.filter { !$0.isPortrait && !$0.isLandscape }
        #expect(landscape.count == 2)
        #expect(portrait.count == 2)
        #expect(neither.count == 1)
        #expect(Set(landscape) == [.landscapeLeft, .landscapeRight])
        #expect(Set(portrait) == [.portrait, .portraitUpsideDown])
        #expect(neither == [.unknown])
    }

    // MARK: - Equality / Hashable (RawRepresentable Int enum)

    @Test func equalityIsReflexiveAndCaseDistinct() {
        #expect(UIInterfaceOrientation.portrait == .portrait)
        #expect(UIInterfaceOrientation.landscapeLeft != .landscapeRight)
        #expect(UIInterfaceOrientation.portrait != .portraitUpsideDown)
        #expect(UIInterfaceOrientation.unknown != .portrait)
    }

    @Test func equalImpliesEqualHashAndRawValue() {
        // Equal values must share a hash and a raw value.
        let a = UIInterfaceOrientation.landscapeRight
        let b = UIInterfaceOrientation(rawValue: 3)
        #expect(b == a)
        #expect(b?.hashValue == a.hashValue)
        #expect(b?.rawValue == a.rawValue)
    }

    @Test func hashableUsableInSet() {
        var set = Set<UIInterfaceOrientation>()
        set.insert(.portrait)
        set.insert(.portrait) // duplicate
        set.insert(.landscapeLeft)
        #expect(set.count == 2)
        #expect(set.contains(.portrait))
        #expect(set.contains(.landscapeLeft))
        #expect(!set.contains(.landscapeRight))
    }

    @Test func usableAsDictionaryKey() {
        // Hashable lets the enum key a dictionary; round-trip a few classifications.
        let table: [UIInterfaceOrientation: String] = [
            .unknown: "n",
            .portrait: "p",
            .portraitUpsideDown: "pud",
            .landscapeLeft: "ll",
            .landscapeRight: "lr",
        ]
        #expect(table.count == 5)
        #expect(table[.landscapeLeft] == "ll")
        #expect(table[.landscapeRight] == "lr")
        #expect(table[.portrait] == "p")
    }

    // MARK: - Sendability (compile-time + concurrency hammer)

    @Test func isSendable() {
        // Compiles only if UIInterfaceOrientation is Sendable. The polyfill declares
        // `: Int, Sendable`; UIKit's NS_ENUM (under NS_HEADER_AUDIT sendability) imports as
        // Sendable as well. Nested function => no top-level name collision.
        func requireSendable<T: Sendable>(_: T.Type) {}
        requireSendable(UIInterfaceOrientation.self)
    }

    @Test func concurrentReadsAreConsistent() async {
        // Hammer the value-type getters from many concurrent tasks and assert that the
        // classification observed for each case never changes (no data race / no torn read).
        // UIInterfaceOrientation is a Sendable value type, so this is safe and deterministic.
        let cases: [UIInterfaceOrientation] = [
            .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight,
        ]
        let expected: [(isPortrait: Bool, isLandscape: Bool, rawValue: Int)] = [
            (false, false, 0), (true, false, 1), (true, false, 2), (false, true, 4), (false, true, 3),
        ]

        let mismatches = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    var bad = 0
                    for i in cases.indices {
                        let o = cases[i]
                        if o.isPortrait != expected[i].isPortrait { bad += 1 }
                        if o.isLandscape != expected[i].isLandscape { bad += 1 }
                        if o.rawValue != expected[i].rawValue { bad += 1 }
                        // round-trip stability under concurrency
                        if UIInterfaceOrientation(rawValue: o.rawValue) != o { bad += 1 }
                    }
                    return bad
                }
            }
            var total = 0
            for await partial in group { total += partial }
            return total
        }

        #expect(mismatches == 0)
    }

    // MARK: - Large / repeated sweep (time-bounded)

    @Test func repeatedRawValueLookupIsStable() {
        // 100_000 lookups across a fixed 0...9 pattern; every valid raw value (0...4)
        // must resolve, every other value (5...9) must be nil. Fully deterministic.
        var resolved = 0
        var nils = 0
        for i in 0..<100_000 {
            // Sweep through 0...9 so we exercise both valid (0...4) and invalid (5...9) bands.
            let raw = i % 10
            if let o = UIInterfaceOrientation(rawValue: raw) {
                resolved += 1
                #expect(o.rawValue == raw)
                #expect(raw >= 0 && raw <= 4)
            } else {
                nils += 1
                #expect(raw >= 5 && raw <= 9)
            }
        }
        // Each block of 10 contributes 5 valid + 5 invalid.
        #expect(resolved == 50_000)
        #expect(nils == 50_000)
    }
}
