//
//  BinaryFloatingPointToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for BinaryFloatingPoint+Tools.swift
//  Source under test:
//    SwiftCodeBook/Source/Tools/Extension/Foundation/BinaryFloatingPoint+Tools.swift
//
//  Covers the tolerance-aware comparison helpers on BinaryFloatingPoint:
//    equals(_:tolerance:), greaterThan(_:tolerance:), lessThan(_:tolerance:),
//    greaterThanOrEquals(_:tolerance:), lessThanOrEquals(_:tolerance:)
//

import Testing
import Foundation
import CoreGraphics
@testable import SwiftCodeBook

@Suite struct BinaryFloatingPointToolsTests {

    // The default tolerance used by all helpers: Self.ulpOfOne.squareRoot().
    // For Double this is ~1.4901161193847656e-08.
    private static let defaultDoubleTolerance = Double.ulpOfOne.squareRoot()
    private static let defaultFloatTolerance = Float.ulpOfOne.squareRoot()

    // MARK: - equals: happy path & exact equality

    @Test func equalsExactlyEqualValues() {
        #expect((1.0).equals(1.0))
        #expect((0.0).equals(0.0))
        #expect((-3.5).equals(-3.5))
        #expect((123456.789).equals(123456.789))
    }

    @Test func equalsNotEqualBeyondTolerance() {
        #expect(!(1.0).equals(2.0))
        #expect(!(0.0).equals(1.0))
        #expect(!(100.0).equals(100.5))
    }

    // -0.0 == 0.0 is true in IEEE, so the short-circuit `self == other` fires.
    @Test func equalsNegativeZeroAndPositiveZero() {
        #expect((0.0).equals(-0.0))
        #expect((-0.0).equals(0.0))
        #expect((-0.0).equals(-0.0))
    }

    // MARK: - equals: tolerance behavior

    @Test func equalsWithinDefaultTolerance() {
        // Difference smaller than the default tolerance counts as equal.
        let a = 1.0
        let b = 1.0 + Self.defaultDoubleTolerance / 2.0
        #expect(a.equals(b))
        #expect(b.equals(a))
    }

    @Test func equalsAtExactlyDefaultTolerance() {
        // abs(diff) <= tolerance, so a difference equal to the tolerance is "equal".
        let a = 0.0
        let b = Self.defaultDoubleTolerance
        #expect(a.equals(b))
        // Sanity: the difference really is exactly the tolerance value.
        #expect(abs(a - b) == Self.defaultDoubleTolerance)
    }

    @Test func equalsJustBeyondDefaultTolerance() {
        // A difference larger than tolerance is not equal.
        let a = 0.0
        let b = Self.defaultDoubleTolerance * 2.0
        #expect(!a.equals(b))
    }

    @Test func equalsWithCustomLargeTolerance() {
        #expect((1.0).equals(1.4, tolerance: 0.5))
        #expect((1.0).equals(0.6, tolerance: 0.5))
        #expect(!(1.0).equals(1.6, tolerance: 0.5))
    }

    @Test func equalsWithZeroToleranceBehavesLikeExactEquality() {
        #expect((1.0).equals(1.0, tolerance: 0.0))
        #expect(!(1.0).equals(1.0 + Self.defaultDoubleTolerance, tolerance: 0.0))
        #expect(!(1.0).equals(1.0000000001, tolerance: 0.0))
        // Zero tolerance still respects the IEEE -0.0 == 0.0 short-circuit.
        #expect((0.0).equals(-0.0, tolerance: 0.0))
    }

    // abs(tolerance) is taken, so a negative tolerance behaves like its magnitude.
    @Test func equalsWithNegativeToleranceUsesAbsoluteValue() {
        #expect((1.0).equals(1.4, tolerance: -0.5))
        #expect(!(1.0).equals(1.6, tolerance: -0.5))
        // A negative tolerance must yield the same result as its positive magnitude.
        #expect((1.0).equals(1.4, tolerance: -0.5) == (1.0).equals(1.4, tolerance: 0.5))
        #expect((1.0).equals(1.6, tolerance: -0.5) == (1.0).equals(1.6, tolerance: 0.5))
    }

    @Test func equalsAtToleranceBoundaryInclusive() {
        // Boundary: abs(diff) == abs(tolerance) -> equal (<=).
        #expect((10.0).equals(11.0, tolerance: 1.0))
        #expect((10.0).equals(9.0, tolerance: 1.0))
        // Just outside the boundary.
        #expect(!(10.0).equals(11.0, tolerance: 0.9999))
    }

    // MARK: - equals: NaN handling

    @Test func equalsNaNAlwaysFalse() {
        let nan = Double.nan
        #expect(!nan.equals(nan))
        #expect(!nan.equals(1.0))
        #expect(!(1.0).equals(nan))
        #expect(!nan.equals(nan, tolerance: .infinity))
        #expect(!nan.equals(0.0, tolerance: 1_000_000.0))
        // NaN as the tolerance itself: comparison should still fail (NaN <= anything is false).
        #expect(!(1.0).equals(2.0, tolerance: .nan))
    }

    @Test func equalsSignalingNaNAlsoFalse() {
        let snan = Double.signalingNaN
        #expect(!snan.equals(snan))
        #expect(!snan.equals(1.0))
        #expect(!(1.0).equals(snan))
    }

    // All five helpers must be false whenever NaN is involved, regardless of tolerance.
    @Test(arguments: [0.0, -1.0, Double.infinity, -Double.infinity, Double.greatestFiniteMagnitude] as [Double])
    func allHelpersFalseWithNaN(_ other: Double) {
        let nan = Double.nan
        for tol in [Self.defaultDoubleTolerance, 0.0, .infinity, .greatestFiniteMagnitude] as [Double] {
            #expect(!nan.equals(other, tolerance: tol))
            #expect(!nan.greaterThan(other, tolerance: tol))
            #expect(!nan.lessThan(other, tolerance: tol))
            #expect(!nan.greaterThanOrEquals(other, tolerance: tol))
            #expect(!nan.lessThanOrEquals(other, tolerance: tol))
            #expect(!other.equals(nan, tolerance: tol))
            #expect(!other.greaterThan(nan, tolerance: tol))
            #expect(!other.lessThan(nan, tolerance: tol))
            #expect(!other.greaterThanOrEquals(nan, tolerance: tol))
            #expect(!other.lessThanOrEquals(nan, tolerance: tol))
        }
    }

    // MARK: - equals: infinity handling

    @Test func equalsInfinityComparedExactly() {
        let inf = Double.infinity
        let negInf = -Double.infinity
        #expect(inf.equals(inf))
        #expect(negInf.equals(negInf))
        #expect(!inf.equals(negInf))
        #expect(!negInf.equals(inf))
    }

    @Test func equalsInfinityVsFinite() {
        let inf = Double.infinity
        #expect(!inf.equals(0.0))
        #expect(!inf.equals(Double.greatestFiniteMagnitude))
        #expect(!(0.0).equals(inf))
        #expect(!(-Double.infinity).equals(-Double.greatestFiniteMagnitude))
    }

    // Even a huge tolerance cannot make infinity "equal" to a finite value,
    // because the isInfinite branch compares exactly.
    @Test func equalsInfinityIgnoresLargeTolerance() {
        let inf = Double.infinity
        #expect(!inf.equals(0.0, tolerance: .infinity))
        #expect(!inf.equals(Double.greatestFiniteMagnitude, tolerance: .greatestFiniteMagnitude))
    }

    @Test func equalsBothInfiniteSameSignViaExactShortCircuit() {
        // inf == inf is true at the very first check, before the isInfinite branch.
        #expect(Double.infinity.equals(.infinity, tolerance: 0.0))
        #expect((-Double.infinity).equals(-.infinity, tolerance: 0.0))
    }

    // MARK: - equals: extremes & large data

    @Test func equalsGreatestFiniteMagnitude() {
        let g = Double.greatestFiniteMagnitude
        #expect(g.equals(g))
        #expect(!g.equals(-g))
    }

    @Test func equalsLeastNonzeroMagnitude() {
        let tiny = Double.leastNonzeroMagnitude
        #expect(tiny.equals(tiny))
        // tiny is far below the default tolerance, so it is "equal" to 0.
        #expect(tiny.equals(0.0))
        #expect((0.0).equals(tiny))
    }

    // Subnormal and least-normal magnitudes are both well below the default tolerance,
    // so they are "equal" to zero and to each other.
    @Test func equalsSubnormalAndLeastNormalNearZero() {
        let leastNormal = Double.leastNormalMagnitude
        let subnormal = Double.leastNonzeroMagnitude
        #expect(leastNormal.equals(0.0))
        #expect(subnormal.equals(0.0))
        #expect(leastNormal.equals(subnormal))
        // Neither is exactly zero, though.
        #expect(leastNormal != 0.0)
        #expect(subnormal != 0.0)
    }

    // MARK: - equals on other conforming types

    @Test func equalsWorksOnFloat() {
        let a: Float = 1.0
        let b: Float = 1.0 + Self.defaultFloatTolerance / 2.0
        #expect(a.equals(b))
        #expect(!a.equals(2.0))
        #expect(Float.nan.equals(.nan) == false)
        #expect(Float.infinity.equals(.infinity))
        // Float's default tolerance is much coarser than Double's; a gap that is
        // "not equal" for Double is comfortably "equal" for Float.
        #expect(Self.defaultFloatTolerance > Float(Self.defaultDoubleTolerance))
        let c: Float = 1.0
        let d: Float = 1.0 + Self.defaultFloatTolerance / 2.0
        #expect(c.equals(d))
    }

    @Test func equalsWorksOnFloatWithCustomTolerance() {
        let a: Float = 10.0
        #expect(a.equals(10.5, tolerance: 1.0))   // diff 0.5 within tolerance
        #expect(!a.equals(11.5, tolerance: 1.0))  // diff 1.5 beyond tolerance
        #expect(a.greaterThan(8.0, tolerance: 1.0))  // 10 > 8 and diff 2.0 beyond tolerance
        #expect(a.lessThan(11.5, tolerance: 1.0))    // 10 < 11.5 and diff 1.5 beyond tolerance
    }

    @Test func equalsWorksOnCGFloat() {
        let a: CGFloat = 5.0
        #expect(a.equals(5.0))
        #expect(!a.equals(6.0))
        #expect(a.equals(5.4, tolerance: 0.5))
        #expect(a.greaterThan(4.0))   // 5 > 4
        #expect(a.lessThan(6.0))      // 5 < 6
        #expect(CGFloat.nan.equals(.nan) == false)
    }

    // Float16 is another conforming type with an even coarser default tolerance.
    @Test func equalsWorksOnFloat16() {
        let a: Float16 = 4.0
        #expect(a.equals(4.0))
        #expect(!a.equals(2.0))
        #expect(a.equals(4.5, tolerance: 1.0))      // diff 0.5 within tolerance
        #expect(a.greaterThan(2.0, tolerance: 1.0)) // 4 > 2 and diff 2.0 beyond tolerance
        #expect(a.lessThan(6.0, tolerance: 1.0))    // 4 < 6 and diff 2.0 beyond tolerance
        #expect(Float16.infinity.equals(.infinity))
        #expect(Float16.nan.equals(.nan) == false)
    }

    // MARK: - greaterThan

    @Test func greaterThanClearlyGreater() {
        #expect((2.0).greaterThan(1.0))
        #expect((0.0).greaterThan(-1.0))
        #expect((100.5).greaterThan(100.0))
    }

    @Test func greaterThanNotGreaterWhenLessOrEqual() {
        #expect(!(1.0).greaterThan(2.0))
        #expect(!(1.0).greaterThan(1.0))
        #expect(!(-5.0).greaterThan(-4.0))
    }

    // Within tolerance the values are considered equal, so greaterThan is false
    // even though raw > is true.
    @Test func greaterThanFalseWhenWithinTolerance() {
        let bigger = 1.0 + Self.defaultDoubleTolerance / 2.0
        #expect(bigger > 1.0)              // raw comparison
        #expect(!bigger.greaterThan(1.0))  // tolerance-aware comparison
    }

    @Test func greaterThanWithCustomTolerance() {
        #expect(!(1.4).greaterThan(1.0, tolerance: 0.5)) // within tolerance -> equal
        #expect((1.6).greaterThan(1.0, tolerance: 0.5))  // beyond tolerance -> greater
        // Boundary: a difference exactly equal to the tolerance counts as equal,
        // so strictly-greater is false right at the boundary.
        #expect(!(2.0).greaterThan(1.0, tolerance: 1.0))
        #expect((2.0001).greaterThan(1.0, tolerance: 1.0))
    }

    @Test func greaterThanWithNaN() {
        let nan = Double.nan
        #expect(!nan.greaterThan(1.0))
        #expect(!(1.0).greaterThan(nan))
        #expect(!nan.greaterThan(nan))
    }

    @Test func greaterThanWithInfinity() {
        #expect(Double.infinity.greaterThan(Double.greatestFiniteMagnitude))
        #expect(Double.infinity.greaterThan(-.infinity))
        #expect(!Double.infinity.greaterThan(.infinity))
        #expect(!(-Double.infinity).greaterThan(0.0))
    }

    // MARK: - lessThan

    @Test func lessThanClearlyLess() {
        #expect((1.0).lessThan(2.0))
        #expect((-1.0).lessThan(0.0))
        #expect((100.0).lessThan(100.5))
    }

    @Test func lessThanNotLessWhenGreaterOrEqual() {
        #expect(!(2.0).lessThan(1.0))
        #expect(!(1.0).lessThan(1.0))
        #expect(!(-4.0).lessThan(-5.0))
    }

    @Test func lessThanFalseWhenWithinTolerance() {
        let smaller = 1.0 - Self.defaultDoubleTolerance / 2.0
        #expect(smaller < 1.0)            // raw comparison
        #expect(!smaller.lessThan(1.0))   // tolerance-aware comparison
    }

    @Test func lessThanWithCustomTolerance() {
        #expect(!(0.6).lessThan(1.0, tolerance: 0.5)) // within tolerance -> equal
        #expect((0.4).lessThan(1.0, tolerance: 0.5))  // beyond tolerance -> less
        // Boundary: difference exactly equal to the tolerance counts as equal.
        #expect(!(0.0).lessThan(1.0, tolerance: 1.0))
        #expect((0.0).lessThan(1.0001, tolerance: 1.0))
    }

    @Test func lessThanWithNaN() {
        let nan = Double.nan
        #expect(!nan.lessThan(1.0))
        #expect(!(1.0).lessThan(nan))
        #expect(!nan.lessThan(nan))
    }

    @Test func lessThanWithInfinity() {
        #expect((-Double.infinity).lessThan(-Double.greatestFiniteMagnitude))
        #expect((-Double.infinity).lessThan(.infinity))
        #expect(!Double.infinity.lessThan(.infinity))
        #expect(!Double.infinity.lessThan(0.0))
    }

    // MARK: - greaterThanOrEquals

    @Test func greaterThanOrEqualsWhenGreater() {
        #expect((2.0).greaterThanOrEquals(1.0))
        #expect((0.5).greaterThanOrEquals(-0.5))
    }

    @Test func greaterThanOrEqualsWhenEqual() {
        #expect((1.0).greaterThanOrEquals(1.0))
        #expect((0.0).greaterThanOrEquals(-0.0))
    }

    @Test func greaterThanOrEqualsWhenEqualWithinTolerance() {
        let smaller = 1.0 - Self.defaultDoubleTolerance / 2.0
        // smaller < 1.0 raw, but within tolerance -> equals true -> result true.
        #expect(smaller.greaterThanOrEquals(1.0))
    }

    @Test func greaterThanOrEqualsWhenLess() {
        #expect(!(1.0).greaterThanOrEquals(2.0))
        #expect(!(-5.0).greaterThanOrEquals(-4.0))
    }

    @Test func greaterThanOrEqualsWithNaN() {
        let nan = Double.nan
        #expect(!nan.greaterThanOrEquals(1.0))
        #expect(!(1.0).greaterThanOrEquals(nan))
        #expect(!nan.greaterThanOrEquals(nan))
    }

    @Test func greaterThanOrEqualsWithInfinity() {
        #expect(Double.infinity.greaterThanOrEquals(.infinity))
        #expect(Double.infinity.greaterThanOrEquals(0.0))
        #expect(!(-Double.infinity).greaterThanOrEquals(0.0))
    }

    // MARK: - lessThanOrEquals

    @Test func lessThanOrEqualsWhenLess() {
        #expect((1.0).lessThanOrEquals(2.0))
        #expect((-0.5).lessThanOrEquals(0.5))
    }

    @Test func lessThanOrEqualsWhenEqual() {
        #expect((1.0).lessThanOrEquals(1.0))
        #expect((-0.0).lessThanOrEquals(0.0))
    }

    @Test func lessThanOrEqualsWhenEqualWithinTolerance() {
        let bigger = 1.0 + Self.defaultDoubleTolerance / 2.0
        // bigger > 1.0 raw, but within tolerance -> equals true -> result true.
        #expect(bigger.lessThanOrEquals(1.0))
    }

    @Test func lessThanOrEqualsWhenGreater() {
        #expect(!(2.0).lessThanOrEquals(1.0))
        #expect(!(-4.0).lessThanOrEquals(-5.0))
    }

    @Test func lessThanOrEqualsWithNaN() {
        let nan = Double.nan
        #expect(!nan.lessThanOrEquals(1.0))
        #expect(!(1.0).lessThanOrEquals(nan))
        #expect(!nan.lessThanOrEquals(nan))
    }

    @Test func lessThanOrEqualsWithInfinity() {
        #expect(Double.infinity.lessThanOrEquals(.infinity))
        #expect((-Double.infinity).lessThanOrEquals(0.0))
        #expect(!Double.infinity.lessThanOrEquals(0.0))
    }

    // MARK: - Mutual exclusivity & consistency invariants

    // For any two non-NaN values exactly one of {lessThan, equals, greaterThan}
    // should hold under the tolerance partition, and the OrEquals variants must
    // be consistent with their strict counterparts.
    @Test(arguments: [
        (0.0, 0.0),
        (1.0, 2.0),
        (2.0, 1.0),
        (-3.0, -3.0),
        (1.0, 1.0 + Double.ulpOfOne.squareRoot() / 2.0), // within default tolerance
        (1.0, 5.0),
        (-10.0, 10.0),
        (Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude),
        (Double.infinity, 0.0),
        (Double.infinity, Double.infinity),
        (-Double.infinity, Double.infinity),
    ] as [(Double, Double)])
    func trichotomyAndConsistency(_ pair: (Double, Double)) {
        let (a, b) = pair
        let lt = a.lessThan(b)
        let eq = a.equals(b)
        let gt = a.greaterThan(b)

        // Exactly one of the three holds (a strict trichotomy).
        let trueCount = [lt, eq, gt].filter { $0 }.count
        #expect(trueCount == 1, "Expected exactly one of <, ==, > for (\(a), \(b)) but got lt=\(lt) eq=\(eq) gt=\(gt)")

        // OrEquals variants must equal the union of the strict + equality result.
        #expect(a.greaterThanOrEquals(b) == (gt || eq))
        #expect(a.lessThanOrEquals(b) == (lt || eq))

        // equals must be symmetric.
        #expect(a.equals(b) == b.equals(a))

        // greaterThan(a,b) must imply lessThan(b,a).
        #expect(a.greaterThan(b) == b.lessThan(a))

        // greaterThanOrEquals(a,b) must mirror lessThanOrEquals(b,a).
        #expect(a.greaterThanOrEquals(b) == b.lessThanOrEquals(a))
    }

    // MARK: - Parameterized custom-tolerance table

    @Test(arguments: [
        // (lhs, rhs, tolerance, expectedEquals)
        (1.0, 1.05, 0.1, true),
        (1.0, 1.15, 0.1, false),
        (5.0, 5.0, 0.0, true),
        (5.0, 5.0001, 0.0, false),
        (100.0, 90.0, 10.0, true),
        (100.0, 89.0, 10.0, false),
        (-1.0, -1.2, 0.3, true),
        (-1.0, -1.5, 0.3, false),
    ] as [(Double, Double, Double, Bool)])
    func equalsTable(_ lhs: Double, _ rhs: Double, _ tol: Double, _ expected: Bool) {
        #expect(lhs.equals(rhs, tolerance: tol) == expected)
        // Symmetry under the same tolerance.
        #expect(rhs.equals(lhs, tolerance: tol) == expected)
        // A negative tolerance of the same magnitude must give the same answer.
        #expect(lhs.equals(rhs, tolerance: -tol) == expected)
        // When equal, neither strict relation may hold; when not equal, exactly one must.
        let lt = lhs.lessThan(rhs, tolerance: tol)
        let gt = lhs.greaterThan(rhs, tolerance: tol)
        if expected {
            #expect(!lt && !gt)
        } else {
            #expect(lt != gt)
        }
    }

    // MARK: - Large-magnitude representative values

    @Test func handlesLargeMagnitudes() {
        let a = 1.0e300
        let b = 1.0e300
        #expect(a.equals(b))
        #expect(!a.equals(2.0e300))
        // Two large numbers differing by less than default tolerance in absolute
        // terms are equal; differing by a huge absolute amount are not.
        #expect(a.greaterThan(1.0e299))
        #expect((1.0e299).lessThan(a))
    }

    // MARK: - Sweep across many values (time-bounded correctness sweep)

    @Test func sweepConsistencyOverManyValues() {
        // Validate the union/strict consistency across a deterministic grid,
        // keeping the work bounded and fast.
        let values: [Double] = stride(from: -50.0, through: 50.0, by: 0.5).map { $0 }
        for a in values {
            for b in values {
                let lt = a.lessThan(b)
                let eq = a.equals(b)
                let gt = a.greaterThan(b)
                #expect([lt, eq, gt].filter { $0 }.count == 1)
                #expect(a.greaterThanOrEquals(b) == (gt || eq))
                #expect(a.lessThanOrEquals(b) == (lt || eq))
            }
        }
    }

    // MARK: - Concurrency: pure value functions must be deterministic under load

    // The helpers are pure (no shared state), so evaluating the same pair from many
    // concurrent tasks must always agree with a single-threaded reference. This is a
    // deterministic stress test: no sleeps, no timing assumptions.
    @Test func concurrentEvaluationIsDeterministic() async {
        let pairs: [(Double, Double, Double)] = [
            (1.0, 2.0, 0.5),
            (2.0, 1.0, 0.5),
            (1.0, 1.0, 0.0),
            (10.0, 10.4, 0.5),
            (-3.0, -3.5, 0.4),
            (0.0, Self.defaultDoubleTolerance, Self.defaultDoubleTolerance),
            (Double.infinity, 0.0, .infinity),
        ]
        // Single-threaded reference results.
        let reference: [(Bool, Bool, Bool, Bool, Bool)] = pairs.map { a, b, t in
            (a.equals(b, tolerance: t),
             a.greaterThan(b, tolerance: t),
             a.lessThan(b, tolerance: t),
             a.greaterThanOrEquals(b, tolerance: t),
             a.lessThanOrEquals(b, tolerance: t))
        }

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<512 {
                group.addTask {
                    for (i, triple) in pairs.enumerated() {
                        let (a, b, t) = triple
                        let r = reference[i]
                        if a.equals(b, tolerance: t) != r.0 { return false }
                        if a.greaterThan(b, tolerance: t) != r.1 { return false }
                        if a.lessThan(b, tolerance: t) != r.2 { return false }
                        if a.greaterThanOrEquals(b, tolerance: t) != r.3 { return false }
                        if a.lessThanOrEquals(b, tolerance: t) != r.4 { return false }
                    }
                    return true
                }
            }
            var allAgree = true
            for await ok in group where !ok { allAgree = false }
            #expect(allAgree)
        }
    }

    // MARK: - Generic constraint exercised through a generic helper

    // Drives the helpers through a generic context so the BinaryFloatingPoint
    // constraint itself is type-checked, not just concrete Double/Float calls.
    private static func assertOrderingInvariants<F: BinaryFloatingPoint>(_ a: F, _ b: F) {
        let lt = a.lessThan(b)
        let eq = a.equals(b)
        let gt = a.greaterThan(b)
        #expect([lt, eq, gt].filter { $0 }.count == 1)
        #expect(a.greaterThanOrEquals(b) == (gt || eq))
        #expect(a.lessThanOrEquals(b) == (lt || eq))
        #expect(a.equals(b) == b.equals(a))
    }

    @Test func genericConstraintHoldsAcrossTypes() {
        Self.assertOrderingInvariants(Double(1.0), Double(2.0))
        Self.assertOrderingInvariants(Double(2.0), Double(2.0))
        Self.assertOrderingInvariants(Float(1.0), Float(2.0))
        Self.assertOrderingInvariants(Float(-1.0), Float(-1.0))
        Self.assertOrderingInvariants(CGFloat(3.0), CGFloat(1.0))
        Self.assertOrderingInvariants(Float16(1.0), Float16(4.0))
    }
}
