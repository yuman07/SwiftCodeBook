//
//  DurationToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Extension/Foundation/Duration+Tools.swift
//
//  Source under test exposes two public computed properties on Duration:
//    - var seconds: TimeInterval        == TimeInterval(self / .seconds(1))
//    - var milliseconds: TimeInterval   == TimeInterval(self / .milliseconds(1))
//
//  Both rely on the standard library `Duration / Duration -> Double` operator,
//  which divides the receiver by the unit Duration to produce a fractional
//  count of that unit (e.g. 500ms.seconds == 0.5, 1s.milliseconds == 1000.0).
//
//  Notes on equality strategy:
//  Every exact-equality assertion below was empirically validated against the
//  Swift stdlib `Duration` implementation (including the 1e-18 attosecond case,
//  the 100_000-iteration loop, the `milliseconds == seconds * 1000` invariant,
//  and Double-constructed values such as 1.5 / 0.25 / 0.1 / 1.234). Those all
//  reproduce exactly, so `==` is used to keep the assertions maximally strict.
//  A relative/absolute `approxEqual` helper is retained only as a guard for
//  genuinely uncertain Double->Duration round-trips.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct DurationToolsTests {

    // MARK: - Helpers

    /// A reasonably tight relative/absolute tolerance for floating point
    /// comparisons. Retained only as a guard for Double->Duration round-trips
    /// where sub-ulp rounding could theoretically appear.
    private static let absTolerance: Double = 1e-9

    private func approxEqual(_ a: Double, _ b: Double, tol: Double = absTolerance) -> Bool {
        if a == b { return true }
        if a.isNaN || b.isNaN { return false }
        let diff = abs(a - b)
        if diff <= tol { return true }
        // Relative tolerance for large magnitudes.
        let scale = max(abs(a), abs(b))
        return diff <= tol * scale
    }

    // MARK: - seconds: happy path

    @Test func secondsOfOneSecond() {
        #expect(Duration.seconds(1).seconds == 1.0)
    }

    @Test func secondsOfWholeSeconds() {
        #expect(Duration.seconds(5).seconds == 5.0)
        #expect(Duration.seconds(60).seconds == 60.0)
        #expect(Duration.seconds(3600).seconds == 3600.0)
    }

    @Test func secondsOfMilliseconds() {
        #expect(Duration.milliseconds(500).seconds == 0.5)
        #expect(Duration.milliseconds(250).seconds == 0.25)
        #expect(Duration.milliseconds(1000).seconds == 1.0)
        #expect(Duration.milliseconds(1).seconds == 0.001)
    }

    @Test func secondsOfMicroseconds() {
        #expect(Duration.microseconds(1).seconds == 1e-06)
        #expect(Duration.microseconds(1_000).seconds == 0.001)
        #expect(Duration.microseconds(1_000_000).seconds == 1.0)
    }

    @Test func secondsOfNanoseconds() {
        #expect(Duration.nanoseconds(1).seconds == 1e-09)
        #expect(Duration.nanoseconds(1_000_000_000).seconds == 1.0)
    }

    // MARK: - milliseconds: happy path

    @Test func millisecondsOfOneMillisecond() {
        #expect(Duration.milliseconds(1).milliseconds == 1.0)
    }

    @Test func millisecondsOfOneSecond() {
        #expect(Duration.seconds(1).milliseconds == 1000.0)
    }

    @Test func millisecondsOfWholeSeconds() {
        #expect(Duration.seconds(2).milliseconds == 2000.0)
        #expect(Duration.seconds(60).milliseconds == 60_000.0)
    }

    @Test func millisecondsOfMilliseconds() {
        #expect(Duration.milliseconds(500).milliseconds == 500.0)
        #expect(Duration.milliseconds(123).milliseconds == 123.0)
        #expect(Duration.milliseconds(0).milliseconds == 0.0)
    }

    @Test func millisecondsOfMicroseconds() {
        #expect(Duration.microseconds(1).milliseconds == 0.001)
        #expect(Duration.microseconds(1_000).milliseconds == 1.0)
    }

    @Test func millisecondsOfNanoseconds() {
        #expect(Duration.nanoseconds(1).milliseconds == 1e-06)
        #expect(Duration.nanoseconds(1_000_000).milliseconds == 1.0)
    }

    // MARK: - Zero

    @Test func zeroDuration() {
        let z = Duration.zero
        #expect(z.seconds == 0.0)
        #expect(z.milliseconds == 0.0)
        // Zero must be exactly +0.0 (not -0.0) so downstream sign checks behave.
        #expect(z.seconds.sign == .plus)
        #expect(z.milliseconds.sign == .plus)
    }

    @Test func explicitZeroConstructions() {
        #expect(Duration.seconds(0).seconds == 0.0)
        #expect(Duration.milliseconds(0).milliseconds == 0.0)
        #expect(Duration(secondsComponent: 0, attosecondsComponent: 0).seconds == 0.0)
        #expect(Duration(secondsComponent: 0, attosecondsComponent: 0).milliseconds == 0.0)
    }

    // MARK: - Negative durations

    @Test func negativeSeconds() {
        #expect(Duration.seconds(-2).seconds == -2.0)
        #expect(Duration.seconds(-2).milliseconds == -2000.0)
    }

    @Test func negativeMilliseconds() {
        #expect(Duration.milliseconds(-500).seconds == -0.5)
        #expect(Duration.milliseconds(-500).milliseconds == -500.0)
    }

    @Test func negativeNanoseconds() {
        #expect(Duration.nanoseconds(-1).seconds == -1e-09)
        #expect(Duration.nanoseconds(-1).milliseconds == -1e-06)
    }

    @Test func negativeFractionalComponents() {
        // -1 second + (-0.5 second worth of attoseconds) == -1.5 s exactly.
        let d = Duration(secondsComponent: -1, attosecondsComponent: -500_000_000_000_000_000)
        #expect(d.seconds == -1.5)
        #expect(d.milliseconds == -1500.0)
    }

    // MARK: - Fractional second constructions (Double -> Duration round-trips)

    @Test func fractionalSecondsViaSecondsInitializer() {
        // Duration.seconds(Double) builds the closest representable Duration.
        // These were verified to round-trip exactly, so == is used; approxEqual
        // remains as a safety net only if a future toolchain shifts rounding.
        #expect(Duration.seconds(1.5).seconds == 1.5)
        #expect(Duration.seconds(1.5).milliseconds == 1500.0)
        #expect(Duration.seconds(0.25).seconds == 0.25)
        #expect(Duration.seconds(0.25).milliseconds == 250.0)
    }

    @Test func fractionalSecondsViaComponents() {
        // 1 second + 234 * 10^15 attoseconds == 1.234 s (verified exact).
        let d = Duration(secondsComponent: 1, attosecondsComponent: 234_000_000_000_000_000)
        #expect(d.seconds == 1.234)
        #expect(d.milliseconds == 1234.0)
    }

    @Test func nonBinaryRepresentableFraction() {
        // 0.1 is the classic non-binary-representable decimal; the property must
        // still equal the Double literal 0.1 because both go through the same
        // Double rounding. Guarded with approxEqual to document the intent.
        #expect(approxEqual(Duration.seconds(0.1).seconds, 0.1))
        #expect(approxEqual(Duration.seconds(0.1).milliseconds, 100.0))
    }

    @Test func halfSecondViaAttoseconds() {
        // 5 * 10^17 attoseconds == 0.5 s exactly.
        let half = Duration(secondsComponent: 0, attosecondsComponent: 500_000_000_000_000_000)
        #expect(half.seconds == 0.5)
        #expect(half.milliseconds == 500.0)
    }

    // MARK: - Sub-nanosecond / attosecond precision boundaries

    @Test func oneAttosecond() {
        let atto = Duration(secondsComponent: 0, attosecondsComponent: 1)
        // 1 attosecond == 1e-18 s == 1e-15 ms (verified exact).
        #expect(atto.seconds == 1e-18)
        #expect(atto.milliseconds == 1e-15)
    }

    @Test func negativeOneAttosecond() {
        let atto = Duration(secondsComponent: 0, attosecondsComponent: -1)
        #expect(atto.seconds == -1e-18)
        #expect(atto.milliseconds == -1e-15)
    }

    @Test func maxAttosecondsWithinOneSecond() {
        // 999_999_999_999_999_999 atto is one atto shy of a full second; it
        // rounds to 1.0 s in Double, which is within tolerance of 1.0.
        let nearOne = Duration(secondsComponent: 0, attosecondsComponent: 999_999_999_999_999_999)
        #expect(approxEqual(nearOne.seconds, 1.0))
        #expect(nearOne.seconds <= 1.0)
        #expect(approxEqual(nearOne.milliseconds, 1000.0))
    }

    @Test func subMillisecondPrecision() {
        // 1 microsecond is below the millisecond unit; result is fractional.
        #expect(Duration.microseconds(1).milliseconds == 0.001)
        #expect(Duration.microseconds(500).milliseconds == 0.5)
    }

    // MARK: - Relationship invariant: milliseconds == seconds * 1000 (exact)

    @Test(arguments: [
        Duration.seconds(1),
        Duration.seconds(0),
        Duration.seconds(-3),
        Duration.milliseconds(250),
        Duration.milliseconds(-750),
        Duration.microseconds(1_500),
        Duration.nanoseconds(1_000_000_000),
        Duration.seconds(123),
    ])
    func millisecondsIsThousandTimesSeconds(_ d: Duration) {
        // Verified to hold with exact `==` for each of these samples.
        #expect(d.milliseconds == d.seconds * 1000.0)
    }

    // MARK: - Table-driven explicit expectations (exact)

    @Test(arguments: [
        // (duration, expectedSeconds, expectedMilliseconds)
        (Duration.seconds(1), 1.0, 1000.0),
        (Duration.seconds(10), 10.0, 10_000.0),
        (Duration.milliseconds(1), 0.001, 1.0),
        (Duration.milliseconds(500), 0.5, 500.0),
        (Duration.microseconds(1), 1e-06, 0.001),
        (Duration.nanoseconds(1), 1e-09, 1e-06),
        (Duration.zero, 0.0, 0.0),
        (Duration.seconds(-1), -1.0, -1000.0),
    ])
    func tableDrivenValues(_ duration: Duration, _ expectedSeconds: Double, _ expectedMs: Double) {
        #expect(duration.seconds == expectedSeconds)
        #expect(duration.milliseconds == expectedMs)
    }

    // MARK: - Large but time-bounded magnitudes

    @Test func largeSecondMagnitude() {
        let big = Duration.seconds(1_000_000)
        #expect(big.seconds == 1_000_000.0)
        #expect(big.milliseconds == 1_000_000_000.0)
    }

    @Test func veryLargeSecondMagnitude() {
        // Near the upper range still representable cleanly as Double seconds.
        let huge = Duration.seconds(1_000_000_000)
        #expect(huge.seconds == 1_000_000_000.0)
        #expect(huge.milliseconds == 1_000_000_000_000.0)
    }

    @Test func largeNegativeSecondMagnitude() {
        let huge = Duration.seconds(-1_000_000_000)
        #expect(huge.seconds == -1_000_000_000.0)
        #expect(huge.milliseconds == -1_000_000_000_000.0)
    }

    @Test func manyValuesStayConsistent() {
        // Exercise a large but fast loop to surface any precision drift.
        // Includes the off-by-one boundaries 0 and 99_999.
        for i in 0..<100_000 {
            let d = Duration.milliseconds(i)
            // milliseconds property must equal the integer count exactly here.
            #expect(d.milliseconds == Double(i))
        }
    }

    @Test func loopBoundaryEndpoints() {
        // Explicit off-by-one boundary checks for the loop above.
        #expect(Duration.milliseconds(0).milliseconds == 0.0)
        #expect(Duration.milliseconds(99_999).milliseconds == 99_999.0)
        #expect(Duration.milliseconds(100_000).milliseconds == 100_000.0)
        #expect(Duration.milliseconds(100_000).seconds == 100.0)
    }

    // MARK: - Result type is TimeInterval (Double)

    @Test func returnTypesAreTimeInterval() {
        let d = Duration.seconds(1)
        let s: TimeInterval = d.seconds
        let ms: TimeInterval = d.milliseconds
        // TimeInterval is a typealias for Double; assert the runtime type.
        #expect(type(of: s) == Double.self)
        #expect(type(of: ms) == Double.self)
        #expect(s == 1.0)
        #expect(ms == 1000.0)
    }

    // MARK: - Determinism / purity

    @Test func repeatedReadsAreStable() {
        let d = Duration.milliseconds(333)
        let s1 = d.seconds
        let s2 = d.seconds
        let m1 = d.milliseconds
        let m2 = d.milliseconds
        #expect(s1 == s2)
        #expect(m1 == m2)
        #expect(s1 == 0.333)
        #expect(m1 == 333.0)
    }

    // MARK: - Concurrency (Duration is Sendable; properties are pure)

    @Test func concurrentReadsAreConsistent() async {
        let d = Duration.milliseconds(1500)
        let expectedSeconds = d.seconds
        let expectedMs = d.milliseconds

        let allCorrect = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    d.seconds == expectedSeconds && d.milliseconds == expectedMs
                }
            }
            var ok = true
            for await result in group {
                ok = ok && result
            }
            return ok
        }
        #expect(allCorrect)
        #expect(expectedSeconds == 1.5)
        #expect(expectedMs == 1500.0)
    }

    @Test func concurrentDistinctDurations() async {
        // Each child computes for a distinct duration; assert every result.
        // Compared against precomputed expectations so any scheduling order is fine.
        let results = await withTaskGroup(of: (Int, Double, Double).self) { group in
            for i in 0..<500 {
                group.addTask {
                    let d = Duration.milliseconds(i)
                    return (i, d.seconds, d.milliseconds)
                }
            }
            var collected: [(Int, Double, Double)] = []
            for await r in group {
                collected.append(r)
            }
            return collected
        }
        #expect(results.count == 500)
        // Verify every index was seen exactly once (no dropped / duplicated tasks).
        let seen = Set(results.map(\.0))
        #expect(seen.count == 500)
        #expect(seen == Set(0..<500))
        for (i, s, ms) in results {
            #expect(ms == Double(i))
            #expect(s == Double(i) / 1000.0)
        }
    }
}
