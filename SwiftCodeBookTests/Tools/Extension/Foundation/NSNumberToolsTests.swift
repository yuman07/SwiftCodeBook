//
//  NSNumberToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Extension/Foundation/NSNumber+Tools.swift
//
//  Source under test exposes a single public computed property on NSNumber:
//    - var cgFloatValue: CGFloat   == CGFloat(doubleValue)
//
//  The property simply bridges NSNumber's `doubleValue` through the
//  `CGFloat(Double)` initializer. On 64-bit platforms (incl. the iOS 26
//  Simulator) CGFloat is backed by Double, so the conversion is lossless and
//  cgFloatValue should equal doubleValue bit-for-bit, including for the special
//  IEEE-754 values (±0, ±infinity, NaN).
//
//  NOTE: NSNumber is Sendable under Swift 6 strict concurrency (the Foundation
//  overlay declares the conformance), so it may be captured directly inside
//  task-group child closures below.
//

import CoreGraphics
import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct NSNumberToolsTests {

    // MARK: - Helpers

    /// Reinterprets the bit patterns of two CGFloat-derived Doubles for an
    /// exact comparison that also distinguishes +0.0 from -0.0 and treats
    /// matching NaN payloads as equal.
    private func sameBits(_ a: Double, _ b: Double) -> Bool {
        a.bitPattern == b.bitPattern
    }

    // MARK: - Happy path: integers

    @Test func returnsCGFloatForPositiveInteger() {
        let n = NSNumber(value: 42)
        #expect(n.cgFloatValue == CGFloat(42))
        #expect(n.cgFloatValue == CGFloat(n.doubleValue))
    }

    @Test func returnsCGFloatForNegativeInteger() {
        let n = NSNumber(value: -7)
        #expect(n.cgFloatValue == CGFloat(-7))
    }

    @Test func returnsCGFloatForZeroInteger() {
        let n = NSNumber(value: 0)
        #expect(n.cgFloatValue == CGFloat(0))
        // Integer zero bridges to +0.0.
        #expect(sameBits(Double(n.cgFloatValue), 0.0))
    }

    // MARK: - Happy path: floating point

    @Test func returnsCGFloatForDouble() {
        let n = NSNumber(value: 3.14159265358979)
        #expect(n.cgFloatValue == CGFloat(3.14159265358979))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func returnsCGFloatForFloat() {
        // Float -> doubleValue widens the 32-bit value; cgFloatValue must match.
        let f: Float = 1.5
        let n = NSNumber(value: f)
        #expect(n.cgFloatValue == CGFloat(n.doubleValue))
        #expect(n.cgFloatValue == CGFloat(1.5))
    }

    @Test func floatPrecisionMatchesDoubleValueExactly() {
        // 0.1 is not representable in Float; whatever doubleValue produces,
        // cgFloatValue must reproduce it exactly (no extra rounding).
        let n = NSNumber(value: Float(0.1))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    // MARK: - Boundaries: small integer types

    @Test func handlesInt8Min() {
        let n = NSNumber(value: Int8.min)
        #expect(n.cgFloatValue == CGFloat(Double(Int8.min)))
        #expect(n.cgFloatValue == CGFloat(-128))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func handlesUInt8Max() {
        let n = NSNumber(value: UInt8.max)
        #expect(n.cgFloatValue == CGFloat(255))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func handlesInt16Extremes() {
        let lo = NSNumber(value: Int16.min)
        let hi = NSNumber(value: Int16.max)
        #expect(lo.cgFloatValue == CGFloat(Double(Int16.min)))
        #expect(hi.cgFloatValue == CGFloat(Double(Int16.max)))
        #expect(lo.cgFloatValue < hi.cgFloatValue)
    }

    @Test func handlesUInt32Max() {
        let n = NSNumber(value: UInt32.max)
        #expect(n.cgFloatValue == CGFloat(Double(UInt32.max)))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    // MARK: - Boundaries: integer extremes

    @Test func handlesIntMax() {
        let n = NSNumber(value: Int.max)
        #expect(n.cgFloatValue == CGFloat(Double(Int.max)))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func handlesIntMin() {
        let n = NSNumber(value: Int.min)
        #expect(n.cgFloatValue == CGFloat(Double(Int.min)))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func handlesUInt64Max() {
        let n = NSNumber(value: UInt64.max)
        // doubleValue rounds UInt64.max; cgFloatValue must reproduce that.
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    // MARK: - Boundaries: Double extremes & special values

    @Test func handlesGreatestFiniteMagnitude() {
        let n = NSNumber(value: Double.greatestFiniteMagnitude)
        #expect(n.cgFloatValue == CGFloat(Double.greatestFiniteMagnitude))
        #expect(sameBits(Double(n.cgFloatValue), Double.greatestFiniteMagnitude))
    }

    @Test func handlesLeastNonzeroMagnitude() {
        // The smallest positive subnormal Double must survive the bridge
        // without flushing to zero.
        let n = NSNumber(value: Double.leastNonzeroMagnitude)
        #expect(Double(n.cgFloatValue) != 0.0)
        #expect(sameBits(Double(n.cgFloatValue), Double.leastNonzeroMagnitude))
    }

    @Test func handlesLeastNormalMagnitude() {
        let n = NSNumber(value: Double.leastNormalMagnitude)
        #expect(sameBits(Double(n.cgFloatValue), Double.leastNormalMagnitude))
    }

    @Test func handlesPositiveInfinity() {
        let n = NSNumber(value: Double.infinity)
        #expect(n.cgFloatValue == .infinity)
        #expect(Double(n.cgFloatValue).isInfinite)
        #expect(Double(n.cgFloatValue) > 0)
    }

    @Test func handlesNegativeInfinity() {
        let n = NSNumber(value: -Double.infinity)
        #expect(n.cgFloatValue == -.infinity)
        #expect(Double(n.cgFloatValue).isInfinite)
        #expect(Double(n.cgFloatValue) < 0)
    }

    @Test func handlesNaN() {
        let n = NSNumber(value: Double.nan)
        // NaN != NaN, so compare via the isNaN predicate.
        #expect(Double(n.cgFloatValue).isNaN)
    }

    @Test func handlesSignalingNaN() {
        let n = NSNumber(value: Double.signalingNaN)
        #expect(Double(n.cgFloatValue).isNaN)
    }

    @Test func preservesNegativeZero() {
        let n = NSNumber(value: -0.0)
        // -0.0 == 0.0 numerically, but the sign bit should be preserved.
        #expect(n.cgFloatValue == CGFloat(0))
        #expect(Double(n.cgFloatValue).sign == .minus)
        #expect(sameBits(Double(n.cgFloatValue), -0.0))
    }

    @Test func preservesPositiveZero() {
        let n = NSNumber(value: 0.0)
        #expect(Double(n.cgFloatValue).sign == .plus)
        #expect(sameBits(Double(n.cgFloatValue), 0.0))
    }

    // MARK: - Float-backed special values widening through doubleValue

    @Test func handlesFloatPositiveInfinity() {
        let n = NSNumber(value: Float.infinity)
        #expect(Double(n.cgFloatValue).isInfinite)
        #expect(Double(n.cgFloatValue) > 0)
        #expect(n.cgFloatValue == .infinity)
    }

    @Test func handlesFloatNegativeInfinity() {
        let n = NSNumber(value: -Float.infinity)
        #expect(Double(n.cgFloatValue).isInfinite)
        #expect(Double(n.cgFloatValue) < 0)
    }

    @Test func handlesFloatNaN() {
        let n = NSNumber(value: Float.nan)
        #expect(Double(n.cgFloatValue).isNaN)
    }

    @Test func handlesFloatGreatestFiniteMagnitude() {
        // Widening Float.greatestFiniteMagnitude to Double is exact; cgFloatValue
        // must reproduce that widened value bit-for-bit.
        let n = NSNumber(value: Float.greatestFiniteMagnitude)
        #expect(sameBits(Double(n.cgFloatValue), Double(Float.greatestFiniteMagnitude)))
    }

    // MARK: - NSDecimalNumber subclass

    @Test func handlesNSDecimalNumberSubclass() {
        // NSDecimalNumber is an NSNumber subclass, so cgFloatValue is inherited
        // and routes through its doubleValue.
        let n = NSDecimalNumber(string: "12345.6789")
        #expect(n.cgFloatValue == CGFloat(n.doubleValue))
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
    }

    @Test func handlesNSDecimalNumberZero() {
        let n = NSDecimalNumber.zero
        #expect(n.cgFloatValue == CGFloat(0))
        #expect(sameBits(Double(n.cgFloatValue), 0.0))
    }

    // MARK: - Boolean bridging

    @Test func handlesBooleanTrue() {
        let n = NSNumber(value: true)
        #expect(n.cgFloatValue == CGFloat(1))
    }

    @Test func handlesBooleanFalse() {
        let n = NSNumber(value: false)
        #expect(n.cgFloatValue == CGFloat(0))
    }

    // MARK: - Ordering is preserved (conversion is monotonic)

    @Test func conversionPreservesOrdering() {
        let ascending = [-1e9, -42.0, -1.0, 0.0, 1.0, 42.0, 1e9].map {
            NSNumber(value: $0).cgFloatValue
        }
        for i in 1..<ascending.count {
            #expect(ascending[i - 1] < ascending[i])
        }
    }

    // MARK: - Parameterized table over a variety of integer values

    @Test(arguments: [
        Int.min, -1_000_000, -1, 0, 1, 2, 100, 1_000_000, Int.max,
    ])
    func cgFloatValueEqualsDoubleValueForInts(_ raw: Int) {
        let n = NSNumber(value: raw)
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
        #expect(n.cgFloatValue == CGFloat(n.doubleValue))
    }

    // MARK: - Parameterized table over a variety of double values

    @Test(arguments: [
        -123.456, -1.0, -0.5, 0.0, 0.5, 1.0, 42.0, 1e-300, 1e300, .pi,
    ] as [Double])
    func cgFloatValueEqualsDoubleValueForDoubles(_ raw: Double) {
        let n = NSNumber(value: raw)
        #expect(sameBits(Double(n.cgFloatValue), raw))
        #expect(n.cgFloatValue == CGFloat(raw))
    }

    // MARK: - Parameterized table over Float values (widened to Double)

    @Test(arguments: [
        -3.5, -0.25, 0.0, 0.25, 1.0, 2.5, 100.0, Float(0.1), Float(0.2),
    ] as [Float])
    func cgFloatValueMatchesWidenedFloat(_ raw: Float) {
        let n = NSNumber(value: raw)
        // doubleValue is the authoritative widened representation; cgFloatValue
        // must reproduce exactly the same Double.
        #expect(sameBits(Double(n.cgFloatValue), n.doubleValue))
        #expect(sameBits(Double(n.cgFloatValue), Double(raw)))
    }

    // MARK: - Round-trip through NSNumber and back

    @Test func roundTripDoubleThroughCGFloat() {
        let original = 98765.4321
        let n = NSNumber(value: original)
        let cg = n.cgFloatValue
        let back = Double(cg)
        #expect(back == original)
        #expect(sameBits(back, original))
    }

    // MARK: - Idempotence / repeated reads

    @Test func repeatedReadsAreStable() {
        let n = NSNumber(value: 17.25)
        let first = n.cgFloatValue
        for _ in 0..<1000 {
            #expect(n.cgFloatValue == first)
        }
    }

    // MARK: - Concurrency: NSNumber is immutable & the property is a pure read

    @Test func concurrentReadsAreConsistent() async {
        let n = NSNumber(value: 256.5)
        let expected = n.cgFloatValue

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    n.cgFloatValue == expected
                }
            }
            var allMatched = true
            for await ok in group {
                allMatched = allMatched && ok
            }
            #expect(allMatched)
        }
    }

    @Test func concurrentReadsAcrossManyDistinctValues() async {
        let numbers = (0..<1000).map { NSNumber(value: Double($0) + 0.5) }

        let results: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for (i, n) in numbers.enumerated() {
                group.addTask {
                    n.cgFloatValue == CGFloat(Double(i) + 0.5)
                }
            }
            var collected: [Bool] = []
            for await ok in group {
                collected.append(ok)
            }
            return collected
        }

        #expect(results.count == 1000)
        #expect(results.allSatisfy { $0 })
    }

    // MARK: - Large data: build a large set and verify exhaustively

    @Test func largeBatchAllConvertCorrectly() {
        var mismatches = 0
        for i in 0..<100_000 {
            let v = Double(i) * 0.001 - 50.0
            let n = NSNumber(value: v)
            if !sameBits(Double(n.cgFloatValue), v) {
                mismatches += 1
            }
        }
        #expect(mismatches == 0)
    }
}
