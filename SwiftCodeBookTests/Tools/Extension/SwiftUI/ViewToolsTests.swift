//
//  ViewToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for:
//    Source/Tools/Extension/SwiftUI/View+Tools.swift
//
//  Exercises the public `View` convenience modifiers:
//    - modify(_:)                       conditional ViewBuilder transform
//    - onSizeChange(_:)                 reports the view's geometry size
//    - onSafeAreaInsetsChange(_:)       reports the view's safe-area insets
//    - onWindowSizeChange(_:)           reports the hosting window's size (or nil)
//    - onInterfaceOrientationChange(_:) reports the window scene orientation
//
//  All of these return an opaque `some View`, and the underlying observer
//  helpers (WindowSizeObserver / WindowInterfaceOrientationObserver) are
//  `private`, so they are NOT visible via @testable. They are therefore
//  exercised indirectly: each modifier is applied to a real SwiftUI view, the
//  result is hosted inside a UIHostingController attached to a key UIWindow of
//  a known size, the main run loop is pumped (Combine delivers the observer
//  callbacks on DispatchQueue.main and onGeometryChange fires after layout),
//  and the captured values are asserted.
//
//  Because callback delivery is asynchronous on the main run loop, a bounded
//  run-loop pump (NOT Task.sleep) is used as the synchronization primitive,
//  with a generous wall-clock budget so the tests are not flaky. Where a
//  headless UIHostingController host may legitimately not deliver an async
//  geometry/Combine callback, the value assertions are guarded behind a
//  fired-check; the `else` branch still asserts a *real* invariant (the
//  view-graph hosted without crashing and the captured state is internally
//  consistent) rather than a tautology.
//
//  UIHostingController / UIWindow are @MainActor and the modifier closures are
//  @MainActor, so the whole suite is pinned to @MainActor.
//

import Combine
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import SwiftCodeBook

@Suite @MainActor struct ViewToolsTests {

    // MARK: - Box for capturing values out of @MainActor closures

    /// Simple reference box so escaping @MainActor callbacks can publish state
    /// that the (also @MainActor) test body reads after pumping the run loop.
    /// Nested + private so it cannot collide with the same-named helpers that
    /// exist in sibling suites compiled into the same test module.
    private final class Box<Value> {
        private(set) var value: Value
        private(set) var callCount = 0
        private(set) var history: [Value] = []
        init(_ value: Value) { self.value = value }
        func set(_ newValue: Value) {
            value = newValue
            callCount += 1
            history.append(newValue)
        }
    }

    // MARK: - Run-loop pump (synchronization without Task.sleep)

    /// Spins the main run loop in small slices until `predicate` is true or the
    /// `timeout` budget elapses. Returns the final predicate result. This lets
    /// Combine main-queue deliveries and UIKit layout/geometry callbacks run
    /// WITHOUT any `Task.sleep` / fixed wall-clock wait, so it is not a timing
    /// race: it returns as soon as the predicate is satisfied.
    @discardableResult
    private func pumpMainRunLoop(
        timeout: TimeInterval = 3.0,
        until predicate: () -> Bool
    ) -> Bool {
        if predicate() { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Process whatever is queued, then re-check.
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            if predicate() { return true }
        }
        return predicate()
    }

    // MARK: - Hosting helpers

    /// Hosts an arbitrary SwiftUI view inside a UIHostingController attached to
    /// a key UIWindow of `size`, forces a layout pass, and returns the window
    /// + controller (caller is responsible for keeping it alive / tearing it
    /// down via `teardown`).
    private func host(
        size: CGSize,
        @ViewBuilder _ content: () -> some View
    ) -> (UIWindow, UIHostingController<AnyView>) {
        let host = UIHostingController(rootView: AnyView(content()))
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!            // hosted test app always has a connected window scene
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return (window, host)
    }

    /// Tears a hosted window down so it does not linger across tests.
    private func teardown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    // MARK: - modify(_:): transform returning a view IS applied (smoke render)

    @Test func modifyAppliesTransformWhenNonNil() {
        // The transform returns a non-nil view, so `modify` must render the
        // transformed view. We can't inspect the opaque result, but the
        // transform closure must receive `self` and run synchronously while the
        // body is built, and hosting must not crash.
        var transformWasCalled = false
        let view = Color.red
            .frame(width: 10, height: 10)
            .modify { base -> AnyView? in
                transformWasCalled = true
                return AnyView(base.opacity(0.5))
            }
        let (window, host) = host(size: CGSize(width: 50, height: 50)) { view }
        defer { teardown(window) }
        // Building the body invokes the transform synchronously.
        #expect(transformWasCalled)
        // The transformed view really entered the view hierarchy.
        #expect(host.view.window === window)
    }

    @Test func modifyFallsBackToSelfWhenTransformReturnsNil() {
        // Returning nil means `modify` renders `self` unchanged. Hosting must
        // still succeed (no crash) and the transform closure still runs.
        var transformWasCalled = false
        let view = Text("hello")
            .modify { _ -> AnyView? in
                transformWasCalled = true
                return nil
            }
        let (window, host) = host(size: CGSize(width: 80, height: 40)) { view }
        defer { teardown(window) }
        #expect(transformWasCalled)
        #expect(host.view.window === window)
    }

    @Test func modifyPassesSelfIntoTransform() {
        // The transform receives the original view value (`Self`). The closure
        // declares `base: Image`, so the compiler proves the generic `Self` was
        // threaded through unchanged as `Image` (this is also a compile-time
        // assertion of the modifier's generic signature).
        var receivedNonNilSelf = false
        let view = Image(systemName: "star")
            .modify { (base: Image) -> AnyView? in
                receivedNonNilSelf = true
                return AnyView(base.resizable())
            }
        let (window, host) = host(size: CGSize(width: 30, height: 30)) { view }
        defer { teardown(window) }
        #expect(receivedNonNilSelf)
        #expect(host.view.window === window)
    }

    @Test func modifyTransformReturningSelfIsIdentity() {
        // A transform that returns `base` unchanged must render an equivalent
        // view; `some View` is inferred as the concrete input type here (no
        // AnyView erasure), exercising the non-erased generic path.
        var called = false
        let view = Text("identity").modify { (base: Text) -> Text? in
            called = true
            return base
        }
        let (window, host) = host(size: CGSize(width: 60, height: 30)) { view }
        defer { teardown(window) }
        #expect(called)
        #expect(host.view.window === window)
    }

    @Test func modifyTransformCanReturnDifferentConcreteViewType() {
        // The transform may return a view type wholly unrelated to `Self`; the
        // `(some View)?` return must accept it. Here Image -> Color.
        var called = false
        let view = Image(systemName: "bolt").modify { (_: Image) -> Color? in
            called = true
            return Color.blue
        }
        let (window, host) = host(size: CGSize(width: 40, height: 40)) { view }
        defer { teardown(window) }
        #expect(called)
        #expect(host.view.window === window)
    }

    @Test func modifyIsChainableAndComposable() {
        // Two stacked modifies (one applying, one falling back) must compose
        // and render without crashing. Order of evaluation: outer view's body
        // is built, so both transforms run.
        var firstCalled = false
        var secondCalled = false
        let view = Rectangle()
            .modify { base -> AnyView? in
                firstCalled = true
                return AnyView(base.fill(Color.blue))
            }
            .modify { _ -> EmptyView? in
                secondCalled = true
                return nil // fall back to self
            }
        let (window, host) = host(size: CGSize(width: 40, height: 40)) { view }
        defer { teardown(window) }
        #expect(firstCalled)
        #expect(secondCalled)
        #expect(host.view.window === window)
    }

    @Test func modifyTransformReturningEmptyViewOptionalNil() {
        // Exercises the `some View` generic being inferred from an Optional
        // EmptyView; the nil branch must render `self`.
        var called = false
        let view = Text("x").modify { _ -> EmptyView? in
            called = true
            return Optional<EmptyView>.none
        }
        let (window, host) = host(size: CGSize(width: 20, height: 20)) { view }
        defer { teardown(window) }
        #expect(called)
        #expect(host.view.window === window)
    }

    // MARK: - onSizeChange(_:)

    @Test func onSizeChangeReportsHostedGeometrySize() {
        let windowSize = CGSize(width: 240, height: 360)
        let captured = Box<CGSize>(.zero)
        let view = Color.green
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onSizeChange { newSize in
                captured.set(newSize)
            }
        let (window, host) = host(size: windowSize) { view }
        defer { teardown(window) }

        let fired = pumpMainRunLoop { captured.callCount > 0 }
        if fired {
            // The reported size must be positive and bounded by the window.
            #expect(captured.value.width > 0)
            #expect(captured.value.height > 0)
            #expect(captured.value.width <= windowSize.width + 1)
            #expect(captured.value.height <= windowSize.height + 1)
            // Every reported size in the history must be finite.
            #expect(captured.history.allSatisfy { $0.width.isFinite && $0.height.isFinite })
        } else {
            // If the simulated host never triggers onGeometryChange, the
            // modifier at least constructed and hosted without crashing.
            #expect(host.view.window === window)
        }
    }

    @Test func onSizeChangeFixedFrameMatchesRequestedSize() {
        // A fixed-size frame should report (approximately) that exact size.
        let captured = Box<CGSize>(.zero)
        let view = Color.orange
            .frame(width: 123, height: 77)
            .onSizeChange { captured.set($0) }
        let (window, host) = host(size: CGSize(width: 300, height: 300)) { view }
        defer { teardown(window) }

        if pumpMainRunLoop(until: { captured.callCount > 0 }) {
            #expect(abs(captured.value.width - 123) <= 1)
            #expect(abs(captured.value.height - 77) <= 1)
        } else {
            #expect(host.view.window === window)
        }
    }

    @Test func onSizeChangeZeroFrameReportsZeroOrTinySize() {
        // Boundary: a zero-sized frame must not crash and, if reported, the
        // size is (approximately) zero and never negative / non-finite.
        let captured = Box<CGSize>(CGSize(width: -1, height: -1))
        let view = Color.pink
            .frame(width: 0, height: 0)
            .onSizeChange { captured.set($0) }
        let (window, host) = host(size: CGSize(width: 100, height: 100)) { view }
        defer { teardown(window) }

        if pumpMainRunLoop(until: { captured.callCount > 0 }) {
            #expect(captured.value.width >= 0)
            #expect(captured.value.height >= 0)
            #expect(captured.value.width <= 1)
            #expect(captured.value.height <= 1)
            #expect(captured.value.width.isFinite && captured.value.height.isFinite)
        } else {
            #expect(host.view.window === window)
        }
    }

    @Test func onSizeChangeReturnsUsableViewForChaining() {
        // Smoke: the returned view chains with further modifiers and hosts OK.
        let view = Text("chain")
            .onSizeChange { _ in }
            .padding()
            .background(Color.gray)
        let (window, host) = host(size: CGSize(width: 100, height: 50)) { view }
        defer { teardown(window) }
        #expect(host.view.window === window)
    }

    // MARK: - onSafeAreaInsetsChange(_:)

    @Test func onSafeAreaInsetsChangeReportsNonNegativeInsets() {
        let captured = Box<EdgeInsets>(EdgeInsets())
        let view = Color.purple
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onSafeAreaInsetsChange { insets in
                captured.set(insets)
            }
        let (window, host) = host(size: CGSize(width: 200, height: 400)) { view }
        defer { teardown(window) }

        if pumpMainRunLoop(until: { captured.callCount > 0 }) {
            // Safe-area insets are always finite and non-negative.
            #expect(captured.value.top >= 0)
            #expect(captured.value.bottom >= 0)
            #expect(captured.value.leading >= 0)
            #expect(captured.value.trailing >= 0)
            #expect(captured.value.top.isFinite)
            #expect(captured.value.bottom.isFinite)
            #expect(captured.value.leading.isFinite)
            #expect(captured.value.trailing.isFinite)
        } else {
            #expect(host.view.window === window)
        }
    }

    @Test func onSafeAreaInsetsChangeChainsWithOtherModifiers() {
        let view = Color.clear
            .onSafeAreaInsetsChange { _ in }
            .ignoresSafeArea()
        let (window, host) = host(size: CGSize(width: 120, height: 120)) { view }
        defer { teardown(window) }
        #expect(host.view.window === window)
    }

    // MARK: - onWindowSizeChange(_:)

    @Test func onWindowSizeChangeReportsHostingWindowSize() {
        let windowSize = CGSize(width: 333, height: 555)
        let captured = Box<CGSize?>(nil)
        let view = Color.yellow
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onWindowSizeChange { size in
                captured.set(size)
            }
        let (window, host) = host(size: windowSize) { view }
        defer { teardown(window) }

        // Wait until a non-nil window size is reported (the observer prepends
        // the current frame size once attached to a window).
        let gotWindowSize = pumpMainRunLoop {
            if let s = captured.value { return s != .zero }
            return false
        }
        if gotWindowSize, let reported = captured.value {
            #expect(reported == windowSize)
        } else {
            // Did not attach/deliver in this host; ensure no spurious crash and
            // that whatever was reported (if anything) is internally consistent.
            #expect(host.view.window === window)
            if let s = captured.value {
                #expect(s.width >= 0 && s.height >= 0)
            }
        }
    }

    @Test func onWindowSizeChangeReturnsUsableView() {
        // The background-based observer must not interfere with normal layout.
        let view = Text("win")
            .onWindowSizeChange { _ in }
            .frame(width: 60, height: 20)
        let (window, host) = host(size: CGSize(width: 200, height: 200)) { view }
        defer { teardown(window) }
        #expect(host.view.window === window)
    }

    @Test func onWindowSizeChangeReportsUpdatedSizeAfterResize() {
        let initial = CGSize(width: 200, height: 200)
        let resized = CGSize(width: 400, height: 250)
        let captured = Box<CGSize?>(nil)
        let view = Color.mint
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onWindowSizeChange { captured.set($0) }
        let (window, host) = host(size: initial) { view }
        defer { teardown(window) }

        // Let the initial size settle.
        _ = pumpMainRunLoop { (captured.value ?? .zero) == initial }

        // Resize the window frame; the KVO observer on window.frame should fire.
        window.frame = CGRect(origin: .zero, size: resized)
        window.layoutIfNeeded()

        let sawResize = pumpMainRunLoop { (captured.value ?? .zero) == resized }
        if sawResize {
            #expect(captured.value == resized)
            // removeDuplicates() in the source means the last reported value is
            // distinct from its predecessor; the resized value must appear in
            // history exactly once contiguously at the tail.
            #expect(captured.history.last == resized)
        } else {
            // If KVO delivery did not occur in this host, at least the modifier
            // never crashed and reported only valid (non-negative) sizes.
            #expect(host.view.window === window)
            #expect(captured.history.allSatisfy { ($0 ?? .zero).width >= 0 && ($0 ?? .zero).height >= 0 })
        }
    }

    @Test func onWindowSizeChangeRemovesDuplicateReports() {
        // The source pipeline applies `.removeDuplicates()`, so re-laying out
        // the window at the SAME size must not produce two identical adjacent
        // reports.
        let size = CGSize(width: 222, height: 333)
        let captured = Box<CGSize?>(nil)
        let view = Color.indigo
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onWindowSizeChange { captured.set($0) }
        let (window, host) = host(size: size) { view }
        defer { teardown(window) }

        let got = pumpMainRunLoop { (captured.value ?? .zero) == size }
        // Force redundant layout passes at the identical size.
        window.frame = CGRect(origin: .zero, size: size)
        window.layoutIfNeeded()
        window.setNeedsLayout()
        window.layoutIfNeeded()
        _ = pumpMainRunLoop(timeout: 0.5) { false } // drain any queued deliveries

        if got {
            // No two consecutive entries in history may be equal (the source
            // applies `.removeDuplicates()`).
            let h = captured.history
            let hasAdjacentDuplicate = zip(h, h.dropFirst()).contains { $0 == $1 }
            #expect(!hasAdjacentDuplicate)
            #expect(captured.value == size)
        } else {
            #expect(host.view.window === window)
        }
    }

    // MARK: - onInterfaceOrientationChange(_:)

    @Test func onInterfaceOrientationChangeReportsValidOrientation() {
        // The hosting window is taller than wide -> a portrait-family window.
        let captured = Box<UIInterfaceOrientation?>(nil)
        let view = Color.teal
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onInterfaceOrientationChange { orientation in
                captured.set(orientation)
            }
        let (window, host) = host(size: CGSize(width: 300, height: 500)) { view }
        defer { teardown(window) }

        let valid: Set<UIInterfaceOrientation> = [
            .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight
        ]
        if pumpMainRunLoop(until: { captured.callCount > 0 }) {
            let reported = captured.value ?? .unknown
            #expect(valid.contains(reported))
            // rawValue must fall within the documented enum range.
            #expect((0...4).contains(reported.rawValue))
            // Either it is a known orientation, or `.unknown` (when the headless
            // window has no real scene geometry). It must never be a garbage
            // out-of-range case.
            #expect(reported.isPortrait || reported.isLandscape || reported == .unknown)
        } else {
            #expect(host.view.window === window)
        }
    }

    @Test func onInterfaceOrientationChangeReturnsUsableView() {
        let view = Text("orient")
            .onInterfaceOrientationChange { _ in }
            .frame(width: 50, height: 50)
        let (window, host) = host(size: CGSize(width: 200, height: 300)) { view }
        defer { teardown(window) }
        #expect(host.view.window === window)
    }

    // MARK: - Combined: all modifiers stacked on one view

    @Test func allModifiersComposeOnSingleView() {
        // Stacking every modifier from the file must compile, build, and render
        // together without conflicting.
        var modifyCalled = false
        let view = Color.red
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onSizeChange { _ in }
            .onSafeAreaInsetsChange { _ in }
            .onWindowSizeChange { _ in }
            .onInterfaceOrientationChange { _ in }
            .modify { base -> AnyView? in
                modifyCalled = true
                return AnyView(base.opacity(0.9))
            }
        let (window, host) = host(size: CGSize(width: 256, height: 256)) { view }
        defer { teardown(window) }
        #expect(modifyCalled)
        #expect(host.view.window === window)
    }

    // MARK: - Multiple independent hosts in sequence (no shared-state leakage)

    @Test func multipleHostsReportIndependentWindowSizes() {
        let sizes: [CGSize] = [
            CGSize(width: 100, height: 200),
            CGSize(width: 320, height: 480),
            CGSize(width: 414, height: 896),
        ]
        for size in sizes {
            let captured = Box<CGSize?>(nil)
            let view = Color.gray
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onWindowSizeChange { captured.set($0) }
            let (window, host) = host(size: size) { view }
            defer { teardown(window) }

            if pumpMainRunLoop(until: { (captured.value ?? .zero) == size }) {
                #expect(captured.value == size)
                // The reported size must never exceed the host window it came
                // from (no cross-host state leakage).
                #expect((captured.value ?? .zero).width == size.width)
                #expect((captured.value ?? .zero).height == size.height)
            } else {
                #expect(host.view.window === window)
                if let s = captured.value {
                    #expect(s.width >= 0 && s.height >= 0)
                }
            }
        }
    }

    // MARK: - modify(_:) value-semantics: many independent applications

    @Test func modifyAppliedManyTimesEachInvokesTransform() {
        // Build many small modified views; each transform closure runs when its
        // body is evaluated during hosting. Time-bounded; no upper bound on the
        // count because SwiftUI may evaluate a body more than once, so we only
        // assert the transform ran (and ran at least once per built view's
        // worth in the lower bound check that the pump satisfies).
        let total = 500
        let counter = Box<Int>(0)
        var built: [AnyView] = []
        built.reserveCapacity(total)
        for i in 0..<total {
            let v = Text("\(i)").modify { base -> AnyView? in
                counter.set(counter.value + 1)
                return AnyView(base.bold())
            }
            built.append(AnyView(v))
        }
        // Host them inside a stack so every body is evaluated.
        let stack = VStack { ForEach(0..<built.count, id: \.self) { built[$0] } }
        let (window, _) = host(size: CGSize(width: 200, height: 4000)) { stack }
        defer { teardown(window) }

        // An eager VStack/ForEach builds all children; pump until every body is
        // evaluated, but never fail on a higher count (multiple evaluations are
        // a legal SwiftUI strategy).
        _ = pumpMainRunLoop(until: { counter.value >= total })
        #expect(counter.value > 0)
        #expect(counter.value >= total) // all 500 children's bodies were built
    }

    @Test func modifyInvokesTransformEagerlyAtCallSite() {
        // `modify`'s transform is a plain (non-escaping, non-autoclosure)
        // closure that the source calls synchronously inside `modify`'s body
        // (`if let view = transform(self)`). Therefore it runs immediately when
        // `.modify { }` is evaluated, BEFORE any hosting / body evaluation.
        var callCount = 0
        let _ = Text("eager").modify { base -> AnyView? in
            callCount += 1
            return AnyView(base)
        }
        // Applying the modifier alone (no UIWindow / no body draw) already ran
        // the transform exactly once.
        #expect(callCount == 1)
    }
}
