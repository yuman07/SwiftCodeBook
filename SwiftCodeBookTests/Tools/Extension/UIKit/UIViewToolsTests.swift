//
//  UIViewToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIView+Tools.swift
//  Covers the public `UIView` extension:
//    - func removeAllSubviews()
//    - func removeAllGestureRecognizers()
//    - var parentViewController: UIViewController?
//    - var interfaceOrientation: UIInterfaceOrientation
//    - var parentWindowPublisher: AnyPublisher<UIWindow?, Never>
//    - var parentWindowSizePublisher: AnyPublisher<CGSize?, Never>
//    - var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never>
//    - var userInterfaceSizeClassPublisher: AnyPublisher<(horizontal:vertical:), Never>
//    - var userInterfaceStylePublisher: AnyPublisher<UIUserInterfaceStyle, Never>
//
//  Notes:
//  - UIView is @MainActor, so the suite is @MainActor.
//  - The publishers internally hop via `.receive(on: DispatchQueue.main)`, so the
//    initial value is delivered asynchronously; tests await it via an AsyncStream
//    bridge rather than sleeping.
//  - Multi-value tests subscribe synchronously, then mutate state synchronously on
//    the MainActor *before* awaiting. Because `.receive(on: DispatchQueue.main)`
//    defers every delivery to a later run-loop turn, the synchronous mutation is
//    always observed by the subscription before the first element is delivered,
//    making the ordered sequence of emitted values deterministic (no sleeping).
//

import Testing
import Foundation
import UIKit
import Combine
@testable import SwiftCodeBook

@MainActor
@Suite struct UIViewToolsTests {

    // MARK: - Helpers

    /// Thread-safe holder for an `AnyCancellable` so it can be retained while the
    /// `AsyncStream` is alive and released on termination, without capturing a
    /// mutable `var` across the `@Sendable` stream-builder boundary.
    private final class CancellableBox: @unchecked Sendable {
        private let lock = NSLock()
        private var cancellable: AnyCancellable?

        func store(_ c: AnyCancellable) {
            lock.lock(); defer { lock.unlock() }
            cancellable = c
        }

        func clear() {
            lock.lock(); defer { lock.unlock() }
            cancellable = nil
        }
    }

    /// Collects the first `count` values from a Never-failing publisher, awaiting
    /// the main-queue hops without any sleeping.
    ///
    /// `AnyPublisher` is not `Sendable`, so we can't constrain on it. Instead we
    /// bridge the `sink` into an `AsyncStream`: the stream continuation is
    /// `Sendable` and safe to call from the publisher's delivery context, while
    /// iteration of the stream happens back on this `@MainActor` suite. The
    /// `AnyCancellable` is retained for the lifetime of the stream and torn down
    /// in `onTermination`. No sleeping is involved.
    private func collect<P: Publisher>(
        _ publisher: P,
        count: Int
    ) async -> [P.Output] where P.Failure == Never, P.Output: Sendable {
        await collect(publisher, count: count, afterSubscribe: {})
    }

    /// Like `collect`, but runs `afterSubscribe` synchronously on the MainActor
    /// immediately after the `sink` subscription is established and before any
    /// value is awaited. This is the deterministic hook used by multi-value tests
    /// to mutate state (e.g. attach/detach a window, resize a window) without a
    /// subscription race and without sleeping.
    private func collect<P: Publisher>(
        _ publisher: P,
        count: Int,
        afterSubscribe: @MainActor () -> Void
    ) async -> [P.Output] where P.Failure == Never, P.Output: Sendable {
        let cancellableBox = CancellableBox()
        let stream = AsyncStream<P.Output> { continuation in
            let cancellable = publisher.sink { value in
                continuation.yield(value)
            }
            cancellableBox.store(cancellable)
            continuation.onTermination = { _ in
                cancellableBox.clear()
            }
        }

        // `AsyncStream`'s builder closure runs synchronously when the stream is
        // created (here), so the subscription is live by the time we mutate.
        afterSubscribe()

        var received: [P.Output] = []
        for await value in stream {
            received.append(value)
            if received.count >= count { break }
        }
        return received
    }

    /// Builds a real, scene-backed `UIWindow` with the given frame. The hosted
    /// test bundle runs inside the SwiftCodeBook app, so a `UIWindowScene` is
    /// always connected and is used via the non-deprecated `init(windowScene:)`
    /// (the legacy `UIWindow(frame:)` is deprecated on iOS 26). Use this for
    /// tests that only need a real window of a known size to host a view.
    private func makeWindow(frame: CGRect) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!            // hosted test app always has a connected window scene
        let window = UIWindow(windowScene: scene)
        window.frame = frame
        return window
    }

    /// Builds a `UIWindow` of the given frame that is a real window object but
    /// carries NO `windowScene`, to exercise the "view is in a window, but the
    /// window has no scene" branch (`window?.windowScene == nil` -> `.unknown`).
    /// This is distinct from a window-less view: the view's `window` is non-nil
    /// here, only `windowScene` is nil. The window is created via the
    /// non-deprecated `init(windowScene:)` and then detached from its scene by
    /// nil-ing the (settable, non-deprecated) `windowScene` property, so the
    /// deprecated `UIWindow(frame:)` initializer is not used.
    private func makeSceneless(frame: CGRect) -> UIWindow {
        let window = makeWindow(frame: frame)
        window.windowScene = nil
        return window
    }

    // MARK: - removeAllSubviews

    @Test func removeAllSubviewsFromEmpty() {
        let view = UIView()
        #expect(view.subviews.isEmpty)
        view.removeAllSubviews()
        #expect(view.subviews.isEmpty)
    }

    @Test func removeAllSubviewsSingle() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        #expect(parent.subviews.count == 1)
        #expect(child.superview === parent)

        parent.removeAllSubviews()

        #expect(parent.subviews.isEmpty)
        #expect(child.superview == nil)
    }

    @Test(arguments: [2, 3, 10, 100])
    func removeAllSubviewsMany(n: Int) {
        let parent = UIView()
        var children: [UIView] = []
        for _ in 0..<n {
            let c = UIView()
            parent.addSubview(c)
            children.append(c)
        }
        #expect(parent.subviews.count == n)

        parent.removeAllSubviews()

        #expect(parent.subviews.isEmpty)
        for c in children {
            #expect(c.superview == nil)
        }
    }

    @Test func removeAllSubviewsLarge() {
        let parent = UIView()
        let n = 5_000
        for _ in 0..<n {
            parent.addSubview(UIView())
        }
        #expect(parent.subviews.count == n)
        parent.removeAllSubviews()
        #expect(parent.subviews.isEmpty)
    }

    @Test func removeAllSubviewsDoesNotTouchSuperview() {
        let grandparent = UIView()
        let parent = UIView()
        let child = UIView()
        grandparent.addSubview(parent)
        parent.addSubview(child)

        // Removing all subviews of `parent` should only drop `child`,
        // not detach `parent` from `grandparent`.
        parent.removeAllSubviews()

        #expect(parent.subviews.isEmpty)
        #expect(parent.superview === grandparent)
        #expect(grandparent.subviews.count == 1)
    }

    @Test func removeAllSubviewsIsIdempotent() {
        let parent = UIView()
        parent.addSubview(UIView())
        parent.addSubview(UIView())
        parent.removeAllSubviews()
        #expect(parent.subviews.isEmpty)
        // Calling again must be safe and remain empty.
        parent.removeAllSubviews()
        #expect(parent.subviews.isEmpty)
    }

    @Test func removeAllSubviewsThenReAddRoundTrip() {
        // After clearing, the parent must still be a usable container.
        let parent = UIView()
        parent.addSubview(UIView())
        parent.addSubview(UIView())
        parent.removeAllSubviews()
        #expect(parent.subviews.isEmpty)

        let fresh = UIView()
        parent.addSubview(fresh)
        #expect(parent.subviews.count == 1)
        #expect(fresh.superview === parent)
    }

    // MARK: - removeAllGestureRecognizers

    @Test func removeAllGestureRecognizersWhenNone() {
        let view = UIView()
        // gestureRecognizers is nil or empty by default.
        #expect((view.gestureRecognizers ?? []).isEmpty)
        view.removeAllGestureRecognizers()
        #expect((view.gestureRecognizers ?? []).isEmpty)
    }

    @Test func removeAllGestureRecognizersSingle() {
        let view = UIView()
        let tap = UITapGestureRecognizer()
        view.addGestureRecognizer(tap)
        #expect(view.gestureRecognizers?.count == 1)
        #expect(tap.view === view)

        view.removeAllGestureRecognizers()

        #expect((view.gestureRecognizers ?? []).isEmpty)
        #expect(tap.view == nil)
    }

    @Test(arguments: [2, 5, 25])
    func removeAllGestureRecognizersMany(n: Int) {
        let view = UIView()
        var gestures: [UIGestureRecognizer] = []
        for i in 0..<n {
            let g: UIGestureRecognizer = (i % 2 == 0)
                ? UITapGestureRecognizer()
                : UIPanGestureRecognizer()
            view.addGestureRecognizer(g)
            gestures.append(g)
        }
        #expect(view.gestureRecognizers?.count == n)

        view.removeAllGestureRecognizers()

        #expect((view.gestureRecognizers ?? []).isEmpty)
        for g in gestures {
            #expect(g.view == nil)
        }
    }

    @Test func removeAllGestureRecognizersIsIdempotent() {
        let view = UIView()
        view.addGestureRecognizer(UITapGestureRecognizer())
        view.removeAllGestureRecognizers()
        #expect((view.gestureRecognizers ?? []).isEmpty)
        view.removeAllGestureRecognizers()
        #expect((view.gestureRecognizers ?? []).isEmpty)
    }

    @Test func removeAllGestureRecognizersThenReAddRoundTrip() {
        let view = UIView()
        view.addGestureRecognizer(UITapGestureRecognizer())
        view.removeAllGestureRecognizers()
        #expect((view.gestureRecognizers ?? []).isEmpty)

        let pan = UIPanGestureRecognizer()
        view.addGestureRecognizer(pan)
        #expect(view.gestureRecognizers?.count == 1)
        #expect(pan.view === view)
    }

    // MARK: - parentViewController

    @Test func parentViewControllerNilWhenDetached() {
        let view = UIView()
        #expect(view.parentViewController == nil)
    }

    @Test func parentViewControllerNilWhenInPlainHierarchy() {
        let parent = UIView()
        let child = UIView()
        parent.addSubview(child)
        // No UIViewController anywhere in the responder chain.
        #expect(child.parentViewController == nil)
        #expect(parent.parentViewController == nil)
    }

    @Test func parentViewControllerFindsDirectController() {
        let vc = UIViewController()
        // vc.view is the controller's root view; its `next` responder is the VC.
        let root = vc.view!
        #expect(root.parentViewController === vc)
    }

    @Test func parentViewControllerFindsAncestorController() {
        let vc = UIViewController()
        let root = vc.view!
        let middle = UIView()
        let leaf = UIView()
        root.addSubview(middle)
        middle.addSubview(leaf)

        #expect(leaf.parentViewController === vc)
        #expect(middle.parentViewController === vc)
    }

    @Test func parentViewControllerFindsNearestController() {
        // Parent VC -> child VC. The deepest view should resolve to the nearest VC.
        let parentVC = UIViewController()
        let childVC = UIViewController()
        parentVC.addChild(childVC)
        parentVC.view.addSubview(childVC.view)
        childVC.didMove(toParent: parentVC)

        let leaf = UIView()
        childVC.view.addSubview(leaf)

        #expect(leaf.parentViewController === childVC)
    }

    @Test func parentViewControllerResolvesContentVCInsideNavigationController() {
        // In a navigation stack the content VC is the *nearest* responder for its
        // own view subtree; the navigation controller sits further up the chain.
        let content = UIViewController()
        let nav = UINavigationController(rootViewController: content)
        // Force the navigation controller's view hierarchy to load.
        nav.loadViewIfNeeded()
        content.loadViewIfNeeded()

        let leaf = UIView()
        content.view.addSubview(leaf)

        // Nearest VC owning `leaf`'s subtree is the content VC, not the nav VC.
        #expect(leaf.parentViewController === content)
        // The content VC's own root view also resolves to the content VC.
        #expect(content.view.parentViewController === content)
    }

    // MARK: - interfaceOrientation (synchronous getter)

    @Test func interfaceOrientationUnknownWithoutWindow() {
        // A view with no window/scene has no effective geometry -> .unknown.
        let view = UIView()
        #expect(view.interfaceOrientation == .unknown)
    }

    @Test func interfaceOrientationUnknownWithScenelessWindow() {
        // Attached to a window that has no windowScene -> still .unknown.
        let window = makeSceneless(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        let view = UIView()
        window.addSubview(view)
        #expect(view.interfaceOrientation == .unknown)
    }

    @Test func interfaceOrientationIsOneOfKnownCases() {
        // Whatever it resolves to, it must be a valid UIInterfaceOrientation case.
        let view = UIView()
        let valid: Set<UIInterfaceOrientation> = [
            .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight
        ]
        #expect(valid.contains(view.interfaceOrientation))
    }

    // MARK: - parentWindowPublisher

    @Test func parentWindowPublisherInjectsObserverSubview() {
        let view = UIView()
        let before = view.subviews.count
        _ = view.parentWindowPublisher
        // Accessing the publisher lazily adds a single private observer subview.
        #expect(view.subviews.count == before + 1)
    }

    @Test func parentWindowPublisherReusesObserverSubview() {
        let view = UIView()
        _ = view.parentWindowPublisher
        let afterFirst = view.subviews.count
        _ = view.parentWindowPublisher
        // A second access must reuse the existing observer, not add another.
        #expect(view.subviews.count == afterFirst)
        // Accessing it many more times must still keep exactly one observer.
        for _ in 0..<10 { _ = view.parentWindowPublisher }
        #expect(view.subviews.count == afterFirst)
    }

    @Test func parentWindowPublisherEmitsNilWhenNoWindow() async {
        let view = UIView()
        let values = await collect(view.parentWindowPublisher, count: 1)
        #expect(values.count == 1)
        // The single emitted element is a nil UIWindow?.
        #expect(values.first == .some(nil))
    }

    @Test func parentWindowPublisherEmitsWindowWhenAttached() async throws {
        let window = makeWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = UIView()
        window.addSubview(view)

        let values = await collect(view.parentWindowPublisher, count: 1)
        let first = try #require(values.first)
        #expect(first === window)
    }

    @Test func parentWindowPublisherEmitsNilAfterDetach() async throws {
        // Start attached -> first value is the window; detach synchronously after
        // subscribing -> the observer's didMoveToWindow fires -> nil is emitted.
        let window = makeWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = UIView()
        window.addSubview(view)

        let values = await collect(view.parentWindowPublisher, count: 2, afterSubscribe: {
            view.removeFromSuperview()
        })

        #expect(values.count == 2)
        let first = try #require(values.first)
        #expect(first === window)
        // Second emission reflects the detach.
        #expect(values.last == .some(nil))
    }

    @Test func parentWindowPublisherEmitsWindowAfterLateAttach() async throws {
        // Start detached -> first value nil; attach synchronously after
        // subscribing -> the window is emitted as the second value.
        let window = makeWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = UIView()

        let values = await collect(view.parentWindowPublisher, count: 2, afterSubscribe: {
            window.addSubview(view)
        })

        #expect(values.count == 2)
        #expect(values.first == .some(nil))
        let last = try #require(values.last)
        #expect(last === window)
    }

    // MARK: - parentWindowSizePublisher

    @Test func parentWindowSizePublisherEmitsNilWhenNoWindow() async {
        let view = UIView()
        let values = await collect(view.parentWindowSizePublisher, count: 1)
        #expect(values.count == 1)
        // No window -> the single emitted element is a nil CGSize?.
        #expect(values.first == .some(nil))
    }

    @Test func parentWindowSizePublisherEmitsWindowSize() async throws {
        let size = CGSize(width: 200, height: 300)
        let window = makeWindow(frame: CGRect(origin: .zero, size: size))
        let view = UIView()
        window.addSubview(view)

        let values = await collect(view.parentWindowSizePublisher, count: 1)
        let first = try #require(values.first)
        #expect(first == size)
    }

    @Test func parentWindowSizePublisherReactsToFrameChange() async throws {
        // First value is the initial size; resizing the window synchronously after
        // subscribing pushes a distinct second size via the window.frame KVO branch.
        let initialSize = CGSize(width: 200, height: 300)
        let newSize = CGSize(width: 375, height: 812)
        let window = makeWindow(frame: CGRect(origin: .zero, size: initialSize))
        let view = UIView()
        window.addSubview(view)

        let values = await collect(view.parentWindowSizePublisher, count: 2, afterSubscribe: {
            window.frame = CGRect(origin: .zero, size: newSize)
        })

        #expect(values.count == 2)
        #expect(values.first == .some(initialSize))
        #expect(values.last == .some(newSize))
    }

    // MARK: - interfaceOrientationPublisher

    @Test func interfaceOrientationPublisherEmitsInitialValue() async throws {
        let view = UIView()
        let values = await collect(view.interfaceOrientationPublisher, count: 1)
        let first = try #require(values.first)
        let valid: Set<UIInterfaceOrientation> = [
            .unknown, .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight
        ]
        #expect(valid.contains(first))
    }

    @Test func interfaceOrientationPublisherUnknownWhenNoScene() async throws {
        // A window with no windowScene (not attached to a scene) -> .unknown.
        let window = makeSceneless(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let view = UIView()
        window.addSubview(view)

        let values = await collect(view.interfaceOrientationPublisher, count: 1)
        let first = try #require(values.first)
        #expect(first == .unknown)
    }

    @Test func interfaceOrientationPublisherUnknownWhenDetached() async throws {
        // No window at all -> the window-less branch yields .unknown.
        let view = UIView()
        let values = await collect(view.interfaceOrientationPublisher, count: 1)
        let first = try #require(values.first)
        #expect(first == .unknown)
    }

    // MARK: - userInterfaceSizeClassPublisher

    @Test func userInterfaceSizeClassPublisherEmitsInitialValue() async throws {
        let view = UIView()
        // Capture the expected trait values on the MainActor before awaiting.
        let expectedH = view.traitCollection.horizontalSizeClass
        let expectedV = view.traitCollection.verticalSizeClass
        let values = await collect(view.userInterfaceSizeClassPublisher, count: 1)
        let first = try #require(values.first)
        // Initial value mirrors the view's own traitCollection.
        #expect(first.horizontal == expectedH)
        #expect(first.vertical == expectedV)
    }

    @Test func userInterfaceSizeClassPublisherValuesAreValidCases() async throws {
        let view = UIView()
        let values = await collect(view.userInterfaceSizeClassPublisher, count: 1)
        let first = try #require(values.first)
        let valid: Set<UIUserInterfaceSizeClass> = [.unspecified, .compact, .regular]
        #expect(valid.contains(first.horizontal))
        #expect(valid.contains(first.vertical))
    }

    // MARK: - userInterfaceStylePublisher

    @Test func userInterfaceStylePublisherEmitsInitialValue() async throws {
        let view = UIView()
        let expected = view.traitCollection.userInterfaceStyle
        let values = await collect(view.userInterfaceStylePublisher, count: 1)
        let first = try #require(values.first)
        // Initial value mirrors the view's own traitCollection style.
        #expect(first == expected)
    }

    @Test func userInterfaceStylePublisherValueIsValidCase() async throws {
        let view = UIView()
        let values = await collect(view.userInterfaceStylePublisher, count: 1)
        let first = try #require(values.first)
        let valid: Set<UIUserInterfaceStyle> = [.unspecified, .light, .dark]
        #expect(valid.contains(first))
    }

    @Test(arguments: [UIUserInterfaceStyle.dark, .light])
    func userInterfaceStylePublisherReflectsOverride(style: UIUserInterfaceStyle) async throws {
        let view = UIView()
        // The override is applied before the publisher is accessed, so the
        // CurrentValueSubject is seeded from the overridden trait.
        view.overrideUserInterfaceStyle = style
        let values = await collect(view.userInterfaceStylePublisher, count: 1)
        let first = try #require(values.first)
        #expect(first == style)
    }

    // MARK: - Stress: removeAllSubviews under repeated rebuilds

    @Test func removeAllSubviewsRepeatedRebuild() {
        let parent = UIView()
        for round in 1...200 {
            let addCount = (round % 5) + 3
            for _ in 0..<addCount {
                parent.addSubview(UIView())
            }
            parent.removeAllSubviews()
            #expect(parent.subviews.isEmpty)
        }
    }

    @Test func removeAllGestureRecognizersRepeatedRebuild() {
        let view = UIView()
        for round in 1...100 {
            let addCount = (round % 4) + 1
            for i in 0..<addCount {
                view.addGestureRecognizer(i % 2 == 0 ? UITapGestureRecognizer() : UIPanGestureRecognizer())
            }
            view.removeAllGestureRecognizers()
            #expect((view.gestureRecognizers ?? []).isEmpty)
        }
    }

    // MARK: - Multiple publishers on the same view share one observer

    @Test func multiplePublishersShareSingleObserver() {
        let view = UIView()
        _ = view.parentWindowPublisher
        _ = view.parentWindowSizePublisher
        _ = view.interfaceOrientationPublisher
        // parentWindowSize/interfaceOrientation are built on top of
        // parentWindowPublisher, which reuses the single observer subview.
        #expect(view.subviews.count == 1)
    }

    @Test func observerSubviewSurvivesUnrelatedSubviewRemoval() {
        // removeAllSubviews removes the lazily-injected observer too (it is a real
        // subview), but adding a fresh observer afterwards must again be a single one.
        let view = UIView()
        _ = view.parentWindowPublisher
        #expect(view.subviews.count == 1)

        view.removeAllSubviews()
        #expect(view.subviews.isEmpty)

        // Re-accessing the publisher re-injects exactly one observer.
        _ = view.parentWindowPublisher
        #expect(view.subviews.count == 1)
        _ = view.parentWindowSizePublisher
        #expect(view.subviews.count == 1)
    }
}
