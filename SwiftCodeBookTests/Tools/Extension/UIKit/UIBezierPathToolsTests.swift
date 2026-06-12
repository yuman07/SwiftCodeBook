//
//  UIBezierPathToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for UIBezierPath+Tools.swift
//  Source under test:
//    SwiftCodeBook/Source/Tools/Extension/UIKit/UIBezierPath+Tools.swift
//
//  Covers the single public API:
//    convenience init(size: CGSize, rectangleCornerRadii: RectangleCornerRadii)
//
//  The initializer builds a rounded-rectangle path inside CGRect(origin: .zero, size: size).
//  Each corner radius is clamped to [0, maxRadius] where maxRadius = max(0, min(w, h) / 2).
//  The path move()s to (topLeading, 0), then traces 4 arcs + 4 lines and close()s.
//
//  Because the produced UIBezierPath exposes no per-element accessor, the tests assert on
//  deterministic, well-understood geometric invariants: isEmpty, bounds (tangent to the
//  rect on all four edges => equal to the rect), point containment, and clamping behavior
//  for negative / oversized / infinity / NaN radii.
//
//  NOTE on `bounds`: empirically (verified on the iOS 26.4 simulator) UIBezierPath.bounds
//  returns the TIGHT path bounding box (== CGPath.boundingBoxOfPath), not the control-point
//  box. For this construction the arcs are tangent to the rect edges, so bounds == the rect
//  exactly. A small tolerance is kept only to absorb fp noise, but the observed values are
//  exact, so the tests are not flaky.
//
//  NaN: the source computes max(0, min(radius, maxRadius)). Swift's free min(.nan, m) == .nan
//  and max(0, .nan) == 0, so NaN radii clamp DETERMINISTICALLY to 0 (a sharp rect). This is a
//  well-defined result, not undefined behavior; the NaN test asserts that concrete outcome.
//
//  UIBezierPath is a plain NSObject (NOT @MainActor / not Sendable) on this SDK, and the
//  test target builds with SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated under Swift 6 complete
//  concurrency, so the suite is nonisolated and the init may be exercised off the main actor.
//  The concurrency tests only return Sendable values (CGRect / Bool) across task boundaries;
//  the non-Sendable UIBezierPath never escapes its task.
//

import Testing
import Foundation
import UIKit
import SwiftUI
import CoreGraphics
@testable import SwiftCodeBook

@Suite struct UIBezierPathToolsTests {

    // MARK: - Helpers

    private static let tolerance: CGFloat = 1e-9

    private static func radii(
        _ tl: CGFloat,
        _ bl: CGFloat,
        _ br: CGFloat,
        _ tt: CGFloat
    ) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: tl, bottomLeading: bl, bottomTrailing: br, topTrailing: tt)
    }

    private static func uniform(_ r: CGFloat) -> RectangleCornerRadii {
        radii(r, r, r, r)
    }

    private static func approxEqual(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = tolerance) -> Bool {
        abs(a - b) <= tol
    }

    private static func rectsApproxEqual(_ a: CGRect, _ b: CGRect, _ tol: CGFloat = tolerance) -> Bool {
        approxEqual(a.minX, b.minX, tol)
            && approxEqual(a.minY, b.minY, tol)
            && approxEqual(a.width, b.width, tol)
            && approxEqual(a.height, b.height, tol)
    }

    private static func path(_ size: CGSize, _ radii: RectangleCornerRadii) -> UIBezierPath {
        UIBezierPath(size: size, rectangleCornerRadii: radii)
    }

    // MARK: - Basic construction: zero radii (sharp rectangle)

    @Test func zeroRadiiProducesRectBounds() {
        let size = CGSize(width: 100, height: 60)
        let p = Self.path(size, Self.uniform(0))

        #expect(!p.isEmpty)
        #expect(!p.cgPath.isEmpty)
        // With zero radii the path traces the rect edges exactly; bounds == the rect.
        let expected = CGRect(origin: .zero, size: size)
        #expect(Self.rectsApproxEqual(p.bounds, expected))
    }

    @Test func zeroRadiiSharpRectContainsCornersAndCenter() {
        // A sharp (zero-radius) rect fills right up to its corners; the corner regions and
        // the center must all be contained.
        let size = CGSize(width: 100, height: 60)
        let p = Self.path(size, Self.uniform(0))

        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size)))
        #expect(p.contains(CGPoint(x: 50, y: 30)))   // center
        #expect(p.contains(CGPoint(x: 1, y: 1)))     // near top-leading corner (sharp => filled)
        #expect(p.contains(CGPoint(x: 99, y: 59)))   // near bottom-trailing corner
    }

    // MARK: - Rounded corners: bounds stay tangent to the rect

    @Test(arguments: [
        CGSize(width: 100, height: 60),
        CGSize(width: 60, height: 100),
        CGSize(width: 80, height: 80),
        CGSize(width: 200, height: 10),
        CGSize(width: 10, height: 200),
        CGSize(width: 17, height: 53),   // odd / coprime dimensions
    ])
    func roundedRectBoundsEqualRect(size: CGSize) {
        // Arcs are tangent to the edges, so even with rounded corners the bounding box
        // equals the full rect (corners are tangent points, not overshoots).
        let p = Self.path(size, Self.uniform(8))
        let expected = CGRect(origin: .zero, size: size)
        // Observed exact on-device; tiny cushion only for fp noise.
        #expect(Self.rectsApproxEqual(p.bounds, expected, 1e-4))
        #expect(!p.isEmpty)
    }

    @Test func roundedRectContainsCenter() {
        let size = CGSize(width: 120, height: 80)
        let p = Self.path(size, Self.uniform(16))
        #expect(p.contains(CGPoint(x: 60, y: 40)))
    }

    @Test func roundedRectDoesNotContainClippedCorner() {
        // A large corner radius rounds off the top-leading corner; points in the cut-away
        // wedge near (0,0) must NOT be inside the path, while interior points remain inside.
        let size = CGSize(width: 100, height: 100)
        let p = Self.path(size, Self.radii(40, 0, 0, 0))
        // Points inside the cut wedge (outside the rounding arc centered at (40,40), r=40).
        #expect(!p.contains(CGPoint(x: 1, y: 1)))
        #expect(!p.contains(CGPoint(x: 5, y: 5)))
        #expect(!p.contains(CGPoint(x: 0.5, y: 0.5)))
        // Just inside the arc (dist from (40,40) < 40) must be contained.
        #expect(p.contains(CGPoint(x: 39, y: 39)))
        // The non-rounded corners and the center are still inside.
        #expect(p.contains(CGPoint(x: 90, y: 90)))
        #expect(p.contains(CGPoint(x: 50, y: 50)))
    }

    @Test func fullyInscribedCircleContainment() {
        // Uniform radius == maxRadius on a square inscribes a circle. The four corner
        // wedges are cut away; edge midpoints and the center stay inside.
        let size = CGSize(width: 100, height: 100) // maxRadius = 50 -> inscribed circle
        let p = Self.path(size, Self.uniform(50))
        #expect(!p.contains(CGPoint(x: 2, y: 2)))     // corner wedge cut away
        #expect(p.contains(CGPoint(x: 50, y: 50)))    // center
        #expect(p.contains(CGPoint(x: 50, y: 1)))     // top edge midpoint (tangent region)
        #expect(p.contains(CGPoint(x: 1, y: 50)))     // leading edge midpoint
    }

    // MARK: - Clamping: negative radii behave like zero

    @Test func negativeRadiiClampToZero() {
        let size = CGSize(width: 100, height: 60)
        let negative = Self.path(size, Self.uniform(-50))
        let zero = Self.path(size, Self.uniform(0))

        // Negative radii are clamped to 0, producing the same sharp-rect bounds.
        #expect(Self.rectsApproxEqual(negative.bounds, zero.bounds))
        #expect(Self.rectsApproxEqual(negative.bounds, CGRect(origin: .zero, size: size)))
        // Sharp corner => the corner region is filled.
        #expect(negative.contains(CGPoint(x: 1, y: 1)))
    }

    @Test(arguments: [
        CGFloat(-1),
        CGFloat(-0.0001),
        CGFloat(-1000),
        -CGFloat.greatestFiniteMagnitude,
        -CGFloat.leastNonzeroMagnitude,
    ])
    func variousNegativeRadiiAllClampToSharpRect(radius: CGFloat) {
        let size = CGSize(width: 80, height: 50)
        let p = Self.path(size, Self.uniform(radius))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size)))
        #expect(p.contains(CGPoint(x: 40, y: 25)))
        #expect(p.contains(CGPoint(x: 1, y: 1))) // sharp corner stays filled
    }

    // MARK: - Clamping: oversized radii saturate at maxRadius = min(w, h) / 2

    @Test func oversizedUniformRadiiSaturateToMaxRadius() {
        // For an 80x80 square, maxRadius = 40. Asking for 1000 clamps every corner to 40,
        // which yields a circle inscribed in the square. Bounds still equal the square.
        let size = CGSize(width: 80, height: 80)
        let huge = Self.path(size, Self.uniform(1000))
        let exact = Self.path(size, Self.uniform(40))

        #expect(Self.rectsApproxEqual(huge.bounds, exact.bounds, 1e-4))
        #expect(Self.rectsApproxEqual(huge.bounds, CGRect(origin: .zero, size: size), 1e-4))
        #expect(!huge.isEmpty)
        // Both saturate to the inscribed circle -> identical corner-wedge clipping.
        #expect(huge.contains(CGPoint(x: 40, y: 40)))
        #expect(!huge.contains(CGPoint(x: 1, y: 1)))
        #expect(!exact.contains(CGPoint(x: 1, y: 1)))
    }

    @Test func oversizedRadiiOnNonSquareUsesMinDimension() {
        // 200x10 => maxRadius = 5. Requesting 100 clamps to 5 on each corner.
        let size = CGSize(width: 200, height: 10)
        let huge = Self.path(size, Self.uniform(100))
        let clamped = Self.path(size, Self.uniform(5))
        #expect(Self.rectsApproxEqual(huge.bounds, clamped.bounds, 1e-4))
        #expect(Self.rectsApproxEqual(huge.bounds, CGRect(origin: .zero, size: size), 1e-4))
    }

    @Test func radiusExactlyAtMaxRadiusEqualsAboveMax() {
        // Requesting exactly maxRadius should match requesting just above it (both saturate).
        let size = CGSize(width: 100, height: 100) // maxRadius = 50
        let atMax = Self.path(size, Self.uniform(50))
        let aboveMax = Self.path(size, Self.uniform(51))
        #expect(Self.rectsApproxEqual(atMax.bounds, aboveMax.bounds, 1e-4))
    }

    @Test func radiusJustBelowMaxRadiusDiffersFromSharp() {
        // Off-by-one boundary: a radius just below maxRadius rounds the corner, so the
        // extreme corner point is cut away (unlike a sharp rect, which would contain it).
        let size = CGSize(width: 100, height: 100) // maxRadius = 50
        let nearMax = Self.path(size, Self.uniform(49.999))
        #expect(!nearMax.contains(CGPoint(x: 1, y: 1)))  // rounded => corner clipped
        let sharp = Self.path(size, Self.uniform(0))
        #expect(sharp.contains(CGPoint(x: 1, y: 1)))     // sharp => corner filled
    }

    // MARK: - Mixed per-corner radii

    @Test func mixedCornerRadiiBoundsEqualRect() {
        let size = CGSize(width: 120, height: 90)
        let p = Self.path(size, Self.radii(0, 10, 20, 30))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size), 1e-4))
        #expect(!p.isEmpty)
        // Sharp top-leading corner (radius 0) is filled; rounded bottom-trailing (radius 20)
        // clips its extreme corner.
        #expect(p.contains(CGPoint(x: 1, y: 1)))
        #expect(!p.contains(CGPoint(x: 119, y: 89)))
    }

    @Test func mixedClampingPerCorner() {
        // maxRadius for 60x40 == 20. topLeading=100 clamps to 20, others stay as-is.
        let size = CGSize(width: 60, height: 40)
        let requested = Self.path(size, Self.radii(100, 5, 0, 8))
        let clamped = Self.path(size, Self.radii(20, 5, 0, 8))
        #expect(Self.rectsApproxEqual(requested.bounds, clamped.bounds, 1e-4))
    }

    // MARK: - RectangleCornerRadii input plumbing (round-trip + equality)

    @Test func cornerRadiiInitializerRoundTripsValues() {
        let r = Self.radii(1, 2, 3, 4)
        #expect(r.topLeading == 1)
        #expect(r.bottomLeading == 2)
        #expect(r.bottomTrailing == 3)
        #expect(r.topTrailing == 4)
        // Equatable: identical inputs compare equal, differing inputs do not.
        #expect(r == Self.radii(1, 2, 3, 4))
        #expect(r != Self.radii(4, 3, 2, 1))
    }

    // MARK: - Degenerate sizes

    @Test func zeroSizeProducesDegeneratePath() {
        // size .zero => maxRadius = 0, all radii clamp to 0. The path is a degenerate
        // point at the origin. It is constructed (move/line/close issued) so not empty.
        let p = Self.path(.zero, Self.uniform(10))
        #expect(!p.isEmpty)
        #expect(Self.rectsApproxEqual(p.bounds, .zero))
    }

    @Test func zeroWidthLineDegenerate() {
        // Zero width => maxRadius = 0; the path collapses to a vertical segment.
        let size = CGSize(width: 0, height: 50)
        let p = Self.path(size, Self.uniform(10))
        #expect(!p.isEmpty)
        #expect(Self.approxEqual(p.bounds.width, 0))
        #expect(Self.approxEqual(p.bounds.height, 50, 1e-4))
    }

    @Test func zeroHeightLineDegenerate() {
        let size = CGSize(width: 50, height: 0)
        let p = Self.path(size, Self.uniform(10))
        #expect(!p.isEmpty)
        #expect(Self.approxEqual(p.bounds.height, 0))
        #expect(Self.approxEqual(p.bounds.width, 50, 1e-4))
    }

    @Test func oneByOneSize() {
        // maxRadius = 0.5; uniform 0.5 inscribes a tiny circle. Bounds == the unit rect.
        let size = CGSize(width: 1, height: 1)
        let p = Self.path(size, Self.uniform(0.5))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size), 1e-4))
    }

    // MARK: - Large dimensions (time-bounded)

    @Test func veryLargeSizeStillTangentBounds() {
        let size = CGSize(width: 100_000, height: 80_000)
        let p = Self.path(size, Self.uniform(1234))
        // Observed exact on-device; tolerance scaled to absorb large-coordinate fp noise.
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size), 1e-3))
        #expect(!p.isEmpty)
    }

    @Test func constructManyPathsQuickly() {
        // Time-bounded throughput check: building many paths must stay correct.
        for i in 1...5_000 {
            let s = CGSize(width: CGFloat(i % 200 + 1), height: CGFloat(i % 100 + 1))
            let p = Self.path(s, Self.uniform(CGFloat(i % 30)))
            #expect(!p.isEmpty)
            // Bounds must always equal the rect regardless of clamping outcome.
            #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: s), 1e-3))
        }
    }

    // MARK: - Infinity / NaN inputs (documented, deterministic behavior)

    @Test func infiniteRadiusClampsToMaxRadius() {
        // min(.infinity, maxRadius) == maxRadius, so +inf behaves like an oversized radius.
        let size = CGSize(width: 100, height: 100)
        let p = Self.path(size, Self.uniform(.infinity))
        let clamped = Self.path(size, Self.uniform(50))
        #expect(Self.rectsApproxEqual(p.bounds, clamped.bounds, 1e-4))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size), 1e-4))
    }

    @Test func negativeInfiniteRadiusClampsToZero() {
        // max(0, min(-inf, maxRadius)) == max(0, -inf) == 0 => sharp rect.
        let size = CGSize(width: 100, height: 60)
        let p = Self.path(size, Self.uniform(-.infinity))
        let zero = Self.path(size, Self.uniform(0))
        #expect(Self.rectsApproxEqual(p.bounds, zero.bounds))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size)))
        #expect(p.contains(CGPoint(x: 1, y: 1))) // sharp => corner filled
    }

    @Test func nanRadiusClampsToZeroSharpRect() {
        // The source computes max(0, min(radius, maxRadius)). Swift's free functions give
        // min(.nan, m) == .nan and then max(0, .nan) == 0, so NaN clamps DETERMINISTICALLY
        // to 0 -> a sharp rectangle. This is well-defined, not undefined behavior.
        let size = CGSize(width: 100, height: 60)
        let p = Self.path(size, Self.uniform(.nan))
        #expect(!p.isEmpty)
        // bounds are finite and equal the full sharp rect.
        #expect(p.bounds.width.isFinite)
        #expect(p.bounds.height.isFinite)
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size)))
        // Sharp corner (radius clamped to 0) => corner region is filled.
        #expect(p.contains(CGPoint(x: 1, y: 1)))
    }

    @Test func singleNaNCornerStillClampsThatCornerToZero() {
        // Only the top-leading corner is NaN; it clamps to 0 (sharp), others round normally.
        let size = CGSize(width: 100, height: 100)
        let p = Self.path(size, Self.radii(.nan, 30, 30, 30))
        #expect(Self.rectsApproxEqual(p.bounds, CGRect(origin: .zero, size: size), 1e-4))
        #expect(p.contains(CGPoint(x: 1, y: 1)))      // NaN -> 0 -> sharp top-leading corner
        #expect(!p.contains(CGPoint(x: 99, y: 99)))   // rounded bottom-trailing corner clipped
    }

    // MARK: - cgPath consistency

    @Test func cgPathBoundingBoxMatchesBounds() {
        let size = CGSize(width: 140, height: 90)
        let p = Self.path(size, Self.uniform(12))
        let cg = p.cgPath
        #expect(!cg.isEmpty)
        // The path's reported bounds equal the underlying CGPath tight box and the rect.
        let box = cg.boundingBoxOfPath
        #expect(Self.rectsApproxEqual(box, CGRect(origin: .zero, size: size), 1e-4))
        #expect(Self.rectsApproxEqual(box, p.bounds, 1e-4))
    }

    @Test func eachConstructionIsIndependent() {
        // Two separately-built paths with identical inputs must have identical bounds,
        // confirming the init produces a fresh, deterministic value each call.
        let size = CGSize(width: 77, height: 33)
        let a = Self.path(size, Self.radii(3, 6, 9, 12))
        let b = Self.path(size, Self.radii(3, 6, 9, 12))
        #expect(Self.rectsApproxEqual(a.bounds, b.bounds))
        #expect(a !== b) // distinct object instances
    }

    // MARK: - Concurrency (init is pure and touches no shared state)

    @Test func concurrentConstructionIsCorrect() async {
        // Build many paths concurrently. The init touches no shared state, so every produced
        // path must satisfy the tangent-bounds invariant with no crash. Only Sendable values
        // (Bool) cross the task boundary; the UIBezierPath never escapes its task.
        let failures = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1_000 {
                group.addTask {
                    let w = CGFloat(i % 300 + 1)
                    let h = CGFloat((i * 7) % 300 + 1)
                    let size = CGSize(width: w, height: h)
                    let r = CGFloat(i % 50)
                    let p = UIBezierPath(
                        size: size,
                        rectangleCornerRadii: RectangleCornerRadii(
                            topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r
                        )
                    )
                    let expected = CGRect(origin: .zero, size: size)
                    return Self.rectsApproxEqual(p.bounds, expected, 1e-3) && !p.isEmpty
                }
            }
            var failed = 0
            for await ok in group where !ok { failed += 1 }
            return failed
        }
        #expect(failures == 0)
    }

    @Test func concurrentIdenticalInputsProduceIdenticalBounds() async {
        // Hammer with identical inputs from many tasks; all bounds must match the reference.
        let size = CGSize(width: 123, height: 45)
        let reference = Self.path(size, Self.uniform(7)).bounds

        let results: [CGRect] = await withTaskGroup(of: CGRect.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    UIBezierPath(size: size, rectangleCornerRadii: Self.uniform(7)).bounds
                }
            }
            var collected: [CGRect] = []
            for await r in group {
                collected.append(r)
            }
            return collected
        }

        #expect(results.count == 500)
        #expect(results.allSatisfy { Self.rectsApproxEqual($0, reference) })
    }
}
