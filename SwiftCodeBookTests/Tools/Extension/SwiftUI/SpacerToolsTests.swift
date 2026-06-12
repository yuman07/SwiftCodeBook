//
//  SpacerToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/SwiftUI/Spacer+Tools.swift
//
//  The source under test adds three conveniences to SwiftUI's `Spacer`:
//    - `Spacer.zero` -> a `Spacer` built with `minLength: 0`.
//    - `Spacer.height(_:)` -> `some View` (a zero Spacer constrained to a fixed height).
//    - `Spacer.width(_:)`  -> `some View` (a zero Spacer constrained to a fixed width).
//
//  Two complementary strategies are used:
//
//  1. STRUCTURAL / TYPE assertions (always run, fully deterministic, no host):
//     SwiftUI views are opaque, immutable value descriptions. Without ViewInspector
//     (not a dependency) we cannot read back a resolved frame from the value alone,
//     but we CAN assert: `Spacer.zero` has the concrete static type `Spacer` (the
//     declared `Self` return), erases to `any View`, reflects via `Mirror`, and is
//     re-created fresh on every access (computed property, no shared mutable state);
//     `height(_:)`/`width(_:)` build a value for the whole CGFloat domain (0, +/-,
//     fractional, huge, leastNonzeroMagnitude, greatestFiniteMagnitude, +/-infinity,
//     .nan) without trapping, the opaque type is invariant across argument values,
//     it differs from a bare `Spacer`, and `height`/`width` share one composed type
//     (`frame(height:)` and `frame(width:)` route through the same
//     `frame(width:height:alignment:)` overload -> `ModifiedContent<Spacer,_FrameLayout>`).
//
//  2. BEHAVIORAL / LAYOUT assertions (host the view in a real UIHostingController +
//     key UIWindow, force a layout pass, and measure the resolved geometry via
//     `UIHostingController.sizeThatFits(in:)`, which is synchronous & deterministic):
//     a `Spacer.height(h)` resolves to a rendered height ~= h; a `Spacer.width(w)`
//     resolves to a rendered width ~= w; `Spacer.zero` adds NO minimum gap between
//     two fixed children in a stack (minLength == 0). Tolerances absorb sub-point
//     rounding; assertions use generous bounds and never sleep, so they are not flaky.
//
//  NOTE: metatype `==` / `!=` comparisons are computed into local `Bool`s BEFORE
//  being passed to `#expect(...)`, because the `#expect` macro's expression
//  decomposition can mis-resolve a bare `Metatype == Metatype` against the
//  `_OptionalNilComparisonType` `==` overload and fail to compile.
//
//  UIHostingController / UIWindow are @MainActor (and SwiftUI value construction is
//  cheapest on the main actor), so the whole suite is pinned to @MainActor.
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import SwiftCodeBook

@Suite @MainActor struct SpacerToolsTests {

    // MARK: - Helpers

    /// Returns whether two metatypes are identical. Kept out of `#expect` to avoid
    /// the macro's faulty overload resolution on metatype `==`.
    private func sameType(_ a: Any.Type, _ b: Any.Type) -> Bool { a == b }

    /// Hosts a SwiftUI view in a UIHostingController attached to a key window of the
    /// given size, forces a layout pass, and returns the controller + window so the
    /// caller can measure geometry. The window is kept alive by the caller; pass it
    /// to `teardown(_:)` in a `defer`.
    private func host(
        size: CGSize,
        @ViewBuilder _ content: () -> some View
    ) -> (UIHostingController<AnyView>, UIWindow) {
        let controller = UIHostingController(rootView: AnyView(content()))
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!            // hosted test app always has a connected window scene
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return (controller, window)
    }

    /// Tears a hosted window down so it does not linger across tests.
    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// A reasonable tolerance for resolved layout sizes (sub-point rounding, scale).
    private let layoutTolerance: CGFloat = 1.0

    // MARK: - Spacer.zero: concrete type & construction

    @Test func zeroHasConcreteSpacerType() {
        let s = Spacer.zero
        // `zero` is declared to return `Self`, i.e. a concrete `Spacer`, not an
        // opaque `some View`. The dynamic type must therefore be exactly Spacer.
        let isSpacer = sameType(type(of: s), Spacer.self)
        #expect(isSpacer)
    }

    @Test func zeroIsAView() {
        // Compile-time: a `Spacer` is a `View`. Runtime: assigning to an existential
        // must succeed without trapping, preserving the concrete dynamic type.
        let v: any View = Spacer.zero
        let isSpacer = sameType(type(of: v), Spacer.self)
        #expect(isSpacer)
    }

    @Test func zeroIsConstructedRepeatedlyWithoutCrash() {
        // `zero` is a computed property; each access builds a fresh value.
        // Hammer it to be sure there is no hidden shared-mutable-state trap.
        var allSpacers = true
        for _ in 0..<10_000 {
            let s = Spacer.zero
            if !sameType(type(of: s), Spacer.self) { allSpacers = false; break }
        }
        #expect(allSpacers)
    }

    @Test func zeroMirrorsAsSpacer() {
        let mirror = Mirror(reflecting: Spacer.zero)
        let isSpacer = sameType(mirror.subjectType, Spacer.self)
        #expect(isSpacer)
    }

    // MARK: - height(_:) construction across the CGFloat domain

    @Test(arguments: [
        CGFloat(0),
        CGFloat(1),
        CGFloat(-1),
        CGFloat(0.5),
        CGFloat(8),
        CGFloat(44),
        CGFloat(100_000),
        CGFloat(-100_000),
        CGFloat.leastNonzeroMagnitude,
        CGFloat.greatestFiniteMagnitude,
        CGFloat.infinity,
        -CGFloat.infinity,
        CGFloat.nan,
    ])
    func heightBuildsViewForAnyValue(height: CGFloat) {
        // Must not trap for any of these inputs (negative / infinite / NaN included).
        let v = Spacer.height(height)
        // The produced opaque value is a real composed View; reflecting it succeeds
        // and reports the same dynamic type as `type(of:)`.
        let mirror = Mirror(reflecting: v)
        let reflectsSelf = sameType(mirror.subjectType, type(of: v))
        #expect(reflectsSelf)
        // And it can be stored as an existential `any View`.
        let erased: any View = v
        let erasedMatches = sameType(type(of: erased), type(of: v))
        #expect(erasedMatches)
    }

    @Test func heightReturnTypeIsStableAcrossInputs() {
        // The opaque return type of `height(_:)` is a single concrete type chosen at
        // compile time; different argument values must NOT change the dynamic type.
        let a = Spacer.height(0)
        let b = Spacer.height(1234.5)
        let c = Spacer.height(.infinity)
        let d = Spacer.height(.nan)
        let ab = sameType(type(of: a), type(of: b))
        let bc = sameType(type(of: b), type(of: c))
        let cd = sameType(type(of: c), type(of: d))
        #expect(ab)
        #expect(bc)
        #expect(cd)
    }

    @Test func heightTypeIsNotPlainSpacer() {
        // `height(_:)` wraps the Spacer in a frame modifier, so its dynamic type
        // must differ from a bare `Spacer`.
        let framed = Spacer.height(10)
        let isBareSpacer = sameType(type(of: framed), Spacer.self)
        #expect(!isBareSpacer)
    }

    // MARK: - width(_:) construction across the CGFloat domain

    @Test(arguments: [
        CGFloat(0),
        CGFloat(1),
        CGFloat(-1),
        CGFloat(0.25),
        CGFloat(16),
        CGFloat(320),
        CGFloat(100_000),
        CGFloat(-100_000),
        CGFloat.leastNonzeroMagnitude,
        CGFloat.greatestFiniteMagnitude,
        CGFloat.infinity,
        -CGFloat.infinity,
        CGFloat.nan,
    ])
    func widthBuildsViewForAnyValue(width: CGFloat) {
        let v = Spacer.width(width)
        let mirror = Mirror(reflecting: v)
        let reflectsSelf = sameType(mirror.subjectType, type(of: v))
        #expect(reflectsSelf)
        let erased: any View = v
        let erasedMatches = sameType(type(of: erased), type(of: v))
        #expect(erasedMatches)
    }

    @Test func widthReturnTypeIsStableAcrossInputs() {
        let a = Spacer.width(0)
        let b = Spacer.width(987.6)
        let c = Spacer.width(.infinity)
        let d = Spacer.width(.nan)
        let ab = sameType(type(of: a), type(of: b))
        let bc = sameType(type(of: b), type(of: c))
        let cd = sameType(type(of: c), type(of: d))
        #expect(ab)
        #expect(bc)
        #expect(cd)
    }

    @Test func widthTypeIsNotPlainSpacer() {
        let framed = Spacer.width(10)
        let isBareSpacer = sameType(type(of: framed), Spacer.self)
        #expect(!isBareSpacer)
    }

    // MARK: - height vs width relationship

    @Test func heightAndWidthProduceSameComposedFrameType() {
        // `.frame(height:)` and `.frame(width:)` are the *same* underlying modifier
        // overload (frame(width:height:alignment:)), so the opaque composed type of
        // `height(_:)` and `width(_:)` should be identical
        // (`ModifiedContent<Spacer, _FrameLayout>`).
        let h = Spacer.height(10)
        let w = Spacer.width(10)
        let same = sameType(type(of: h), type(of: w))
        #expect(same)
    }

    // MARK: - Behavioral layout: height(_:) resolves to the requested height

    @Test(arguments: [CGFloat(0), CGFloat(8), CGFloat(44), CGFloat(120)])
    func heightResolvesToRequestedHeightWhenHosted(requested: CGFloat) {
        // Host the framed spacer in a tall window and measure the resolved size with
        // a fixed-width / unbounded-height proposal. The fixed frame dimension must
        // resolve to ~= `requested`.
        let view = Spacer.height(requested)
        let (controller, window) = host(size: CGSize(width: 200, height: 1000)) { view }
        defer { teardown(window) }

        let fitted = controller.sizeThatFits(in: CGSize(width: 200, height: 5000))
        // Height should pin to the requested value (within rounding tolerance).
        #expect(abs(fitted.height - requested) <= layoutTolerance)
        // A resolved size must always be finite and non-negative.
        #expect(fitted.height.isFinite)
        #expect(fitted.height >= 0)
        #expect(fitted.width.isFinite)
    }

    // MARK: - Behavioral layout: width(_:) resolves to the requested width

    @Test(arguments: [CGFloat(0), CGFloat(16), CGFloat(120), CGFloat(320)])
    func widthResolvesToRequestedWidthWhenHosted(requested: CGFloat) {
        let view = Spacer.width(requested)
        let (controller, window) = host(size: CGSize(width: 1000, height: 200)) { view }
        defer { teardown(window) }

        let fitted = controller.sizeThatFits(in: CGSize(width: 5000, height: 200))
        #expect(abs(fitted.width - requested) <= layoutTolerance)
        #expect(fitted.width.isFinite)
        #expect(fitted.width >= 0)
        #expect(fitted.height.isFinite)
    }

    // MARK: - Behavioral layout: resolved size is monotonic in the request

    @Test func heightIsMonotonicInRequestedValue() {
        // A larger requested height must never resolve to a smaller rendered height.
        // This is robust regardless of exact sub-point pinning.
        let small = Spacer.height(10)
        let large = Spacer.height(100)
        let (sc, sw) = host(size: CGSize(width: 200, height: 1000)) { small }
        defer { teardown(sw) }
        let (lc, lw) = host(size: CGSize(width: 200, height: 1000)) { large }
        defer { teardown(lw) }
        let sh = sc.sizeThatFits(in: CGSize(width: 200, height: 5000)).height
        let lh = lc.sizeThatFits(in: CGSize(width: 200, height: 5000)).height
        #expect(lh >= sh - layoutTolerance)
        #expect(lh - sh >= 90 - 2 * layoutTolerance) // ~ (100 - 10)
    }

    @Test func widthIsMonotonicInRequestedValue() {
        let small = Spacer.width(10)
        let large = Spacer.width(100)
        let (sc, sw) = host(size: CGSize(width: 1000, height: 200)) { small }
        defer { teardown(sw) }
        let (lc, lw) = host(size: CGSize(width: 1000, height: 200)) { large }
        defer { teardown(lw) }
        let sWidth = sc.sizeThatFits(in: CGSize(width: 5000, height: 200)).width
        let lWidth = lc.sizeThatFits(in: CGSize(width: 5000, height: 200)).width
        #expect(lWidth >= sWidth - layoutTolerance)
        #expect(lWidth - sWidth >= 90 - 2 * layoutTolerance)
    }

    // MARK: - Behavioral layout: Spacer.zero adds no minimum gap (minLength == 0)

    @Test func zeroAddsNoMinimumGapBetweenFixedChildrenInHStack() {
        // Two fixed 40pt boxes separated by `Spacer.zero` inside an HStack with no
        // spacing. Because the spacer's minLength is 0, the intrinsic width of the
        // stack must be just the two boxes (~80pt), NOT 80 + a default spacer gap.
        let widthBox: CGFloat = 40
        let stack = HStack(spacing: 0) {
            Color.clear.frame(width: widthBox, height: 10)
            Spacer.zero
            Color.clear.frame(width: widthBox, height: 10)
        }
        let (controller, window) = host(size: CGSize(width: 1000, height: 100)) { stack }
        defer { teardown(window) }

        // `layoutFittingCompressedSize` (== .zero) asks for the smallest fit, i.e. the
        // content-hugging width. With minLength 0 the spacer contributes nothing, so
        // the compressed width is ~= the two boxes only (no default spacer gap).
        let fitted = controller.sizeThatFits(in: UIView.layoutFittingCompressedSize)
        // Compare against a control HStack that omits the spacer entirely.
        let control = HStack(spacing: 0) {
            Color.clear.frame(width: widthBox, height: 10)
            Color.clear.frame(width: widthBox, height: 10)
        }
        let (controlController, controlWindow) =
            host(size: CGSize(width: 1000, height: 100)) { control }
        defer { teardown(controlWindow) }
        let controlFitted =
            controlController.sizeThatFits(in: UIView.layoutFittingCompressedSize)

        // A zero spacer must not enlarge the compressed width beyond the control.
        #expect(abs(fitted.width - controlFitted.width) <= layoutTolerance)
        #expect(fitted.width.isFinite)
        // Sanity: the boxes themselves must be present in the measured width.
        #expect(fitted.width >= 2 * widthBox - layoutTolerance)
    }

    // MARK: - Behavioral layout: zero height/width does not force positive size

    @Test func heightZeroProducesZeroHeightWhenHosted() {
        let view = Spacer.height(0)
        let (controller, window) = host(size: CGSize(width: 100, height: 500)) { view }
        defer { teardown(window) }
        let fitted = controller.sizeThatFits(in: CGSize(width: 100, height: 5000))
        #expect(abs(fitted.height) <= layoutTolerance)
    }

    @Test func widthZeroProducesZeroWidthWhenHosted() {
        let view = Spacer.width(0)
        let (controller, window) = host(size: CGSize(width: 500, height: 100)) { view }
        defer { teardown(window) }
        let fitted = controller.sizeThatFits(in: CGSize(width: 5000, height: 100))
        #expect(abs(fitted.width) <= layoutTolerance)
    }

    // MARK: - Embedding in a parent view (compile + build + render smoke)

    private struct Host: View {
        let length: CGFloat
        var body: some View {
            VStack(spacing: 0) {
                Spacer.zero
                Spacer.height(length)
                HStack(spacing: 0) {
                    Spacer.width(length)
                    Spacer.zero
                }
            }
        }
    }

    @Test(arguments: [CGFloat(0), CGFloat(20), CGFloat(-5), CGFloat.infinity])
    func helpersComposeInsideAParentView(length: CGFloat) {
        // Building AND rendering the parent view must succeed for representative
        // lengths, proving the helpers are usable in real `@ViewBuilder` contexts.
        let parent = Host(length: length)
        let isHost = sameType(type(of: parent), Host.self)
        #expect(isHost)

        // The body is a pure value description that reflects as a real composed view.
        let body = parent.body
        let mirror = Mirror(reflecting: body)
        let reflectsSelf = sameType(mirror.subjectType, type(of: body))
        #expect(reflectsSelf)

        // Hosting it must not crash and must produce a finite resolved size even when
        // the requested length is infinite (SwiftUI clamps to the proposal).
        let (controller, window) = host(size: CGSize(width: 300, height: 600)) { parent }
        defer { teardown(window) }
        let fitted = controller.sizeThatFits(in: CGSize(width: 300, height: 600))
        #expect(fitted.width.isFinite)
        #expect(fitted.height.isFinite)
        #expect(controller.view.window === window)
    }

    // MARK: - Large-data / stress (time-bounded)

    @Test func buildingManyHelperViewsIsStable() {
        // Construct a large number of helper views to surface any per-call allocation
        // or shared-state issue. Pure value construction, well under a second.
        var heightType: Any.Type?
        var widthType: Any.Type?
        var stable = true
        for i in 0..<50_000 {
            let len = CGFloat(i % 1000)
            let h = Spacer.height(len)
            let w = Spacer.width(len)
            if heightType == nil { heightType = type(of: h) }
            if widthType == nil { widthType = type(of: w) }
            // Dynamic type must remain invariant across iterations.
            if let ht = heightType, !sameType(type(of: h), ht) { stable = false; break }
            if let wt = widthType, !sameType(type(of: w), wt) { stable = false; break }
        }
        #expect(stable)
        let gotHeightType = heightType != nil
        let gotWidthType = widthType != nil
        #expect(gotHeightType)
        #expect(gotWidthType)
        // height and width funnel through the same composed frame type.
        if let ht = heightType, let wt = widthType {
            let same = sameType(ht, wt)
            #expect(same)
        }
    }
}
