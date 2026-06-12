//
//  UIStackViewToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIStackView+Tools.swift
//  Exercises the sole public API:
//    - func removeAllArrangedSubviews()
//
//  The implementation pops `arrangedSubviews.last` repeatedly, calling both
//  `removeArrangedSubview(_:)` AND `last.removeFromSuperview()`. So after the
//  call:
//    * the stack has zero arranged subviews,
//    * every previously-arranged view is detached from the stack's view
//      hierarchy (superview == nil and not present in `stack.subviews`),
//    * subviews that were added directly (NOT arranged) are left untouched,
//    * the stack's own layout configuration and place in any parent hierarchy
//      are unaffected.
//
//  UIStackView is a @MainActor UIKit type and UIView is non-Sendable, so the
//  whole suite is pinned to @MainActor. No concurrency stress is applicable:
//  the API is synchronous and main-actor-isolated; UIViews cannot legally be
//  hammered across tasks. Stress is instead exercised via a large, time-bounded
//  subview count on the main actor.
//

import Foundation
import UIKit
import Testing
@testable import SwiftCodeBook

@Suite @MainActor struct UIStackViewToolsTests {

    // MARK: - Helpers

    /// Builds a stack view populated with `count` distinct arranged subviews.
    /// Returns the stack and the views in arrangement order.
    private func makeStackView(arrangedCount count: Int) -> (UIStackView, [UIView]) {
        let views = (0..<count).map { _ in UIView() }
        let stack = UIStackView(arrangedSubviews: views)
        return (stack, views)
    }

    /// Object-identity set, used to assert no view is silently skipped.
    private func identitySet(_ views: [UIView]) -> Set<ObjectIdentifier> {
        Set(views.map(ObjectIdentifier.init))
    }

    // MARK: - Empty / boundary cases

    @Test func removeAllOnEmptyStackViewIsNoOp() {
        let stack = UIStackView()
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)

        // Must not crash and must remain empty.
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
    }

    @Test func removeAllOnSingleArrangedSubview() throws {
        let (stack, views) = makeStackView(arrangedCount: 1)
        let only = try #require(views.first)
        #expect(stack.arrangedSubviews.count == 1)
        #expect(stack.subviews.count == 1)
        #expect(only.superview === stack)

        stack.removeAllArrangedSubviews()

        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        // The view is detached from the stack via removeFromSuperview().
        #expect(only.superview == nil)
    }

    // MARK: - Main / happy path (boundaries: 0, 1, off-by-one, larger)

    @Test(arguments: [0, 1, 2, 3, 5, 10, 50])
    func removeAllClearsArrangedSubviews(count: Int) {
        let (stack, views) = makeStackView(arrangedCount: count)
        #expect(stack.arrangedSubviews.count == count)
        #expect(stack.subviews.count == count)
        // All views start parented to the stack.
        #expect(views.allSatisfy { $0.superview === stack })

        stack.removeAllArrangedSubviews()

        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        // Every previously-arranged view is detached from any superview.
        #expect(views.allSatisfy { $0.superview == nil })
        // And no removed view lingers as a plain subview.
        let removedIdentities = identitySet(views)
        let survivingIdentities = identitySet(stack.subviews)
        #expect(survivingIdentities.isDisjoint(with: removedIdentities))
    }

    @Test func removeAllIsIdempotent() {
        let (stack, views) = makeStackView(arrangedCount: 4)
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        #expect(views.allSatisfy { $0.superview == nil })

        // A second call on the now-empty stack must be a safe no-op.
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)

        // A third call too, for good measure.
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)
    }

    // MARK: - Round-trip: clear then re-populate

    @Test func stackIsReusableAfterRemoveAll() {
        let (stack, _) = makeStackView(arrangedCount: 3)
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)

        // Re-populate the cleared stack; it must accept new arranged subviews.
        let fresh = (0..<5).map { _ in UIView() }
        fresh.forEach { stack.addArrangedSubview($0) }
        #expect(stack.arrangedSubviews.count == 5)
        #expect(fresh.allSatisfy { $0.superview === stack })

        // And it can be cleared again.
        stack.removeAllArrangedSubviews()
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        #expect(fresh.allSatisfy { $0.superview == nil })
    }

    // MARK: - Mixed arranged + non-arranged subviews

    @Test func removeAllLeavesNonArrangedSubviewsUntouched() {
        let (stack, arranged) = makeStackView(arrangedCount: 3)

        // Plain subviews added directly (NOT arranged) should survive, because
        // the extension only walks `arrangedSubviews`.
        let overlayA = UIView()
        let overlayB = UIView()
        stack.addSubview(overlayA)
        stack.addSubview(overlayB)

        #expect(stack.arrangedSubviews.count == 3)
        #expect(stack.subviews.contains(overlayA))
        #expect(stack.subviews.contains(overlayB))

        stack.removeAllArrangedSubviews()

        #expect(stack.arrangedSubviews.isEmpty)
        // The non-arranged overlays remain subviews of the stack, in order.
        #expect(overlayA.superview === stack)
        #expect(overlayB.superview === stack)
        #expect(stack.subviews == [overlayA, overlayB])
        // Arranged views were detached.
        #expect(arranged.allSatisfy { $0.superview == nil })
        // The arranged views are also not part of `arrangedSubviews` anymore.
        let arrangedIDs = identitySet(arranged)
        let stillArranged = identitySet(stack.arrangedSubviews)
        #expect(stillArranged.isDisjoint(with: arrangedIDs))
    }

    // MARK: - State preservation

    @Test func removeAllPreservesStackViewConfiguration() {
        let (stack, _) = makeStackView(arrangedCount: 6)
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true

        stack.removeAllArrangedSubviews()

        // Removing arranged subviews must not mutate the stack's own layout config.
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.axis == .vertical)
        #expect(stack.alignment == .center)
        #expect(stack.distribution == .equalSpacing)
        #expect(stack.spacing == 12)
        #expect(stack.isLayoutMarginsRelativeArrangement)
    }

    // MARK: - Identity / no view skipped

    @Test func removeAllRemovesEveryDistinctView() {
        let (stack, views) = makeStackView(arrangedCount: 8)
        // Track identities to be sure no view is silently skipped.
        let identities = identitySet(views)
        #expect(identities.count == 8)

        stack.removeAllArrangedSubviews()

        #expect(stack.arrangedSubviews.isEmpty)
        #expect(identitySet(stack.arrangedSubviews).isEmpty)
        #expect(views.allSatisfy { $0.superview == nil })
    }

    // MARK: - Large data (time-bounded stress, all on main actor)

    @Test(.timeLimit(.minutes(1)))
    func removeAllHandlesLargeNumberOfSubviews() {
        let count = 5_000
        let (stack, views) = makeStackView(arrangedCount: count)
        #expect(stack.arrangedSubviews.count == count)
        #expect(stack.subviews.count == count)

        stack.removeAllArrangedSubviews()

        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        #expect(views.allSatisfy { $0.superview == nil })
    }

    // MARK: - Interaction with a real superview hierarchy

    @Test func removeAllDetachesViewsEvenWhenStackIsInHierarchy() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let (stack, views) = makeStackView(arrangedCount: 4)
        container.addSubview(stack)
        stack.frame = container.bounds
        container.layoutIfNeeded()

        #expect(stack.superview === container)
        #expect(stack.arrangedSubviews.count == 4)

        stack.removeAllArrangedSubviews()

        // Stack itself stays in the hierarchy; only its arranged subviews leave.
        #expect(stack.superview === container)
        #expect(container.subviews == [stack])
        #expect(stack.arrangedSubviews.isEmpty)
        #expect(stack.subviews.isEmpty)
        #expect(views.allSatisfy { $0.superview == nil })
    }

    // MARK: - removeArrangedSubview vs full detachment

    /// `removeArrangedSubview(_:)` alone leaves the view in `subviews`; the
    /// extension additionally calls `removeFromSuperview()`. This test pins that
    /// distinction so a regression that drops the `removeFromSuperview()` call
    /// would be caught.
    @Test func removeAllAlsoDetachesFromSubviewsNotJustArrangement() {
        let (stack, views) = makeStackView(arrangedCount: 4)
        #expect(stack.subviews.count == 4)

        stack.removeAllArrangedSubviews()

        // If the implementation only did removeArrangedSubview without
        // removeFromSuperview, these views would still appear in `subviews`.
        #expect(stack.subviews.isEmpty)
        #expect(views.allSatisfy { $0.superview == nil })
    }
}
