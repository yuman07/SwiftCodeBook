//
//  UIViewControllerToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIViewController+Tools.swift
//
//  Exercises the three `UIViewController` containment convenience helpers:
//    - addChildSafely(_:layout:)   — safely embeds a child VC, re-parenting it
//                                     if needed, running an optional layout
//                                     closure, and firing the containment
//                                     callbacks (addChild / didMove).
//    - removeFromParentSafely()    — detaches a VC from its parent (no-op when
//                                     it has no parent), removing its view and
//                                     calling willMove(toParent: nil).
//    - removeAllChildren()         — repeatedly removes the last child until
//                                     none remain.
//
//  Coverage includes the happy path, the two guard branches of
//  addChildSafely (adding self, re-adding an existing child), re-parenting a
//  child that already lives under a different parent, layout-closure
//  invocation/arguments, the containment-callback ordering (willMove/didMove),
//  view-hierarchy side effects, idempotency, empty / single / many boundaries,
//  and a time-bounded large-data stress case.
//
//  UIViewController is a @MainActor UIKit type, so the whole suite is pinned to
//  @MainActor.
//

import Foundation
import UIKit
import Testing
@testable import SwiftCodeBook

@Suite @MainActor struct UIViewControllerToolsTests {

    // MARK: - Helpers

    /// A trivial concrete subclass; UIViewController itself is fine, but a named
    /// subclass makes intent clearer and lets us add per-instance markers.
    private final class ProbeViewController: UIViewController {
        let tag: Int
        init(tag: Int = 0) {
            self.tag = tag
            super.init(nibName: nil, bundle: nil)
        }
        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not implemented") }
    }

    /// Records the containment-lifecycle callbacks UIKit invokes, so we can
    /// assert the exact ordering produced by the helpers. Each entry stores the
    /// observed `parent` argument's identity (or `nil` for a detach).
    private final class RecordingViewController: UIViewController {
        private(set) var willMoveParents: [ObjectIdentifier] = []
        private(set) var willMoveToNilCount = 0
        private(set) var didMoveParents: [ObjectIdentifier] = []
        private(set) var didMoveToNilCount = 0

        var willMoveCallCount: Int { willMoveParents.count + willMoveToNilCount }
        var didMoveCallCount: Int { didMoveParents.count + didMoveToNilCount }

        override func willMove(toParent parent: UIViewController?) {
            if let parent {
                willMoveParents.append(ObjectIdentifier(parent))
            } else {
                willMoveToNilCount += 1
            }
            super.willMove(toParent: parent)
        }

        override func didMove(toParent parent: UIViewController?) {
            if let parent {
                didMoveParents.append(ObjectIdentifier(parent))
            } else {
                didMoveToNilCount += 1
            }
            super.didMove(toParent: parent)
        }
    }

    private func makeParent() -> ProbeViewController { ProbeViewController(tag: -1) }
    private func makeChild(_ tag: Int = 0) -> ProbeViewController { ProbeViewController(tag: tag) }

    // MARK: - addChildSafely: happy path

    @Test func addChildSafelyEstablishesContainment() {
        let parent = makeParent()
        let child = makeChild()

        parent.addChildSafely(child)

        // Containment relationship is established.
        #expect(child.parent === parent)
        #expect(parent.children.contains(child))
        #expect(parent.children.count == 1)
        // The child's view is added to the parent's view.
        #expect(child.view.superview === parent.view)
        #expect(parent.view.subviews.contains(child.view))
    }

    @Test func addChildSafelyInvokesLayoutClosureWithCorrectArguments() async {
        let parent = makeParent()
        let child = makeChild()

        await confirmation("layout closure runs exactly once", expectedCount: 1) { confirm in
            parent.addChildSafely(child) { passedChild, passedParent in
                // The closure receives the exact instances we passed in.
                #expect(passedChild === child)
                #expect(passedParent === parent)
                // By the time layout runs, addChild has already happened and the
                // view is in the hierarchy, but didMove has not yet been called.
                #expect(child.parent === parent)
                #expect(child.view.superview === parent.view)
                confirm()
            }
        }
    }

    @Test func addChildSafelyWithNilLayoutClosureStillWorks() {
        let parent = makeParent()
        let child = makeChild()

        // Explicit nil (matches the default) must be a safe no-op for layout.
        parent.addChildSafely(child, layout: nil)

        #expect(child.parent === parent)
        #expect(child.view.superview === parent.view)
    }

    @Test func addChildSafelyDefaultLayoutArgumentIsNil() {
        let parent = makeParent()
        let child = makeChild()

        // Calling with no trailing closure uses the default (nil) argument and
        // must behave identically to passing `layout: nil`.
        parent.addChildSafely(child)

        #expect(child.parent === parent)
        #expect(child.view.superview === parent.view)
        #expect(parent.children.count == 1)
    }

    // MARK: - addChildSafely: containment-callback ordering

    @Test func addChildSafelyFiresDidMoveExactlyOnceAfterLayout() {
        let parent = makeParent()
        let child = RecordingViewController(nibName: nil, bundle: nil)

        var didMoveCountAtLayoutTime = -1
        parent.addChildSafely(child) { _, _ in
            // Source order: addChild -> addSubview -> layout?() -> didMove.
            // So inside the layout closure, didMove must NOT have fired yet.
            didMoveCountAtLayoutTime = child.didMoveCallCount
        }

        #expect(didMoveCountAtLayoutTime == 0)
        // didMove(toParent: parent) fired exactly once, with the right parent.
        #expect(child.didMoveCallCount == 1)
        #expect(child.didMoveParents == [ObjectIdentifier(parent)])
    }

    @Test func addChildSafelyDoesNotFireWillMoveToNilOnFreshChild() {
        let parent = makeParent()
        let child = RecordingViewController(nibName: nil, bundle: nil)

        parent.addChildSafely(child)

        // A brand-new child has no prior parent, so removeFromParentSafely's
        // guard trips and willMove(toParent: nil) is never invoked.
        #expect(child.willMoveCallCount == 0)
        #expect(child.didMoveCallCount == 1)
    }

    // MARK: - addChildSafely: guard branches

    @Test func addChildSafelyIgnoresAddingSelf() {
        let vc = makeParent()

        // `child != self` guard: adding a VC to itself must be a no-op.
        vc.addChildSafely(vc)

        #expect(vc.children.isEmpty)
        #expect(vc.parent == nil)
        #expect(vc.view.superview == nil)
    }

    @Test func addChildSafelyIgnoresAddingSelfEvenWithLayoutClosure() async {
        let vc = makeParent()

        // The layout closure must NOT run when the self-guard trips.
        await confirmation("layout closure never runs for self", expectedCount: 0) { confirm in
            vc.addChildSafely(vc) { _, _ in
                confirm()
            }
        }
        #expect(vc.children.isEmpty)
    }

    @Test func addChildSafelyIsNoOpWhenChildAlreadyHasSameParent() async {
        let parent = makeParent()
        let child = makeChild()

        parent.addChildSafely(child)
        #expect(parent.children.count == 1)
        let viewBefore = child.view

        // `child.parent != self` guard: re-adding an existing child should NOT
        // run the layout closure and should not duplicate the child.
        await confirmation("layout closure never runs on re-add", expectedCount: 0) { confirm in
            parent.addChildSafely(child) { _, _ in
                confirm()
            }
        }

        #expect(parent.children.count == 1)
        #expect(child.parent === parent)
        #expect(child.view === viewBefore)
        #expect(child.view.superview === parent.view)
        // The parent's view must not have gained a duplicate copy of the view.
        #expect(parent.view.subviews.filter { $0 === child.view }.count == 1)
    }

    @Test func addChildSafelyReAddSameParentDoesNotFireExtraCallbacks() {
        let parent = makeParent()
        let child = RecordingViewController(nibName: nil, bundle: nil)

        parent.addChildSafely(child)
        #expect(child.didMoveCallCount == 1)
        let willMoveBefore = child.willMoveCallCount

        // Re-adding to the same parent hits the guard and must not fire any new
        // containment callbacks.
        parent.addChildSafely(child)

        #expect(child.didMoveCallCount == 1)
        #expect(child.willMoveCallCount == willMoveBefore)
    }

    // MARK: - addChildSafely: re-parenting

    @Test func addChildSafelyReparentsChildFromAnotherParent() {
        let firstParent = makeParent()
        let secondParent = makeParent()
        let child = makeChild()

        firstParent.addChildSafely(child)
        #expect(child.parent === firstParent)
        #expect(firstParent.children.contains(child))

        // Moving the child to a new parent must detach it from the old one first
        // (removeFromParentSafely inside addChildSafely).
        secondParent.addChildSafely(child)

        #expect(child.parent === secondParent)
        #expect(secondParent.children.contains(child))
        #expect(secondParent.children.count == 1)
        // Old parent no longer references the child.
        #expect(firstParent.children.isEmpty)
        #expect(child.view.superview === secondParent.view)
        #expect(child.view.superview !== firstParent.view)
    }

    @Test func addChildSafelyReparentRunsLayoutClosureAndCallbacks() async {
        let firstParent = makeParent()
        let secondParent = makeParent()
        let child = RecordingViewController(nibName: nil, bundle: nil)

        firstParent.addChildSafely(child)
        #expect(child.didMoveCallCount == 1)

        // Re-parenting to a DIFFERENT parent passes the guard, so the layout
        // closure must run, the old parent must detach (willMove(toParent: nil)),
        // and didMove fires again for the new parent.
        await confirmation("layout closure runs on re-parent", expectedCount: 1) { confirm in
            secondParent.addChildSafely(child) { _, _ in confirm() }
        }

        #expect(child.parent === secondParent)
        #expect(firstParent.children.isEmpty)
        // willMove(toParent: nil) fired during the detach from firstParent.
        #expect(child.willMoveToNilCount == 1)
        // didMove fired once for each successful attach (firstParent + secondParent).
        #expect(child.didMoveCallCount == 2)
        #expect(child.didMoveParents.last == ObjectIdentifier(secondParent))
    }

    @Test func addChildSafelyMultipleDistinctChildrenAllAttach() {
        let parent = makeParent()
        let children = (0..<5).map { makeChild($0) }

        for child in children {
            parent.addChildSafely(child)
        }

        #expect(parent.children.count == 5)
        for child in children {
            #expect(child.parent === parent)
            #expect(child.view.superview === parent.view)
        }
        // Insertion order is preserved in both the controllers list and subviews.
        #expect(parent.children.map { ObjectIdentifier($0) }
            == children.map { ObjectIdentifier($0) })
    }

    // MARK: - removeFromParentSafely

    @Test func removeFromParentSafelyDetachesChild() {
        let parent = makeParent()
        let child = makeChild()
        parent.addChildSafely(child)
        #expect(child.parent === parent)

        child.removeFromParentSafely()

        #expect(child.parent == nil)
        #expect(parent.children.isEmpty)
        // The child's view is removed from the parent's view.
        #expect(child.view.superview == nil)
        #expect(!parent.view.subviews.contains(child.view))
    }

    @Test func removeFromParentSafelyFiresWillMoveToNil() {
        let parent = makeParent()
        let child = RecordingViewController(nibName: nil, bundle: nil)
        parent.addChildSafely(child)
        let willMoveToNilBefore = child.willMoveToNilCount

        child.removeFromParentSafely()

        // The detach path must invoke willMove(toParent: nil) exactly once more.
        #expect(child.willMoveToNilCount == willMoveToNilBefore + 1)
        #expect(child.parent == nil)
    }

    @Test func removeFromParentSafelyIsNoOpWhenNoParent() {
        let orphan = makeChild()
        #expect(orphan.parent == nil)

        // The `parent != nil` guard means this must be a safe no-op and must
        // NOT remove the controller's own view from any superview it might
        // happen to have. Here it has none, so nothing changes.
        orphan.removeFromParentSafely()

        #expect(orphan.parent == nil)
        #expect(orphan.view.superview == nil)
    }

    @Test func removeFromParentSafelyNoOpDoesNotDetachViewFromForeignSuperview() {
        // A controller with NO parent whose view nonetheless lives inside some
        // unrelated superview: the `parent != nil` guard must short-circuit and
        // leave that view in place (the helper must not call removeFromSuperview).
        let orphan = makeChild()
        let host = UIView()
        host.addSubview(orphan.view)
        #expect(orphan.parent == nil)
        #expect(orphan.view.superview === host)

        orphan.removeFromParentSafely()

        #expect(orphan.parent == nil)
        #expect(orphan.view.superview === host)
        #expect(host.subviews.contains(orphan.view))
    }

    @Test func removeFromParentSafelyIsIdempotent() {
        let parent = makeParent()
        let child = makeChild()
        parent.addChildSafely(child)

        child.removeFromParentSafely()
        #expect(child.parent == nil)

        // Second call: parent is now nil, so the guard makes it a no-op.
        child.removeFromParentSafely()
        #expect(child.parent == nil)
        #expect(parent.children.isEmpty)
    }

    @Test func removeFromParentSafelyOnlyAffectsTheReceiver() {
        let parent = makeParent()
        let a = makeChild(1)
        let b = makeChild(2)
        parent.addChildSafely(a)
        parent.addChildSafely(b)
        #expect(parent.children.count == 2)

        a.removeFromParentSafely()

        // Only `a` is detached; `b` stays put.
        #expect(a.parent == nil)
        #expect(a.view.superview == nil)
        #expect(b.parent === parent)
        #expect(b.view.superview === parent.view)
        #expect(parent.children.count == 1)
        #expect(parent.children.first === b)
    }

    // MARK: - removeAllChildren

    @Test func removeAllChildrenOnEmptyIsNoOp() {
        let parent = makeParent()
        #expect(parent.children.isEmpty)

        // Must not crash / loop forever on an empty container.
        parent.removeAllChildren()

        #expect(parent.children.isEmpty)
    }

    @Test func removeAllChildrenWithSingleChild() {
        let parent = makeParent()
        let child = makeChild()
        parent.addChildSafely(child)
        #expect(parent.children.count == 1)

        parent.removeAllChildren()

        #expect(parent.children.isEmpty)
        #expect(child.parent == nil)
        #expect(child.view.superview == nil)
    }

    @Test(arguments: [2, 3, 5, 10, 50])
    func removeAllChildrenDetachesEveryChild(count: Int) {
        let parent = makeParent()
        let children = (0..<count).map { makeChild($0) }
        for child in children {
            parent.addChildSafely(child)
        }
        #expect(parent.children.count == count)

        parent.removeAllChildren()

        #expect(parent.children.isEmpty)
        // Every previously-attached child is fully detached.
        #expect(children.allSatisfy { $0.parent == nil })
        #expect(children.allSatisfy { $0.view.superview == nil })
    }

    @Test func removeAllChildrenIsIdempotent() {
        let parent = makeParent()
        for i in 0..<4 { parent.addChildSafely(makeChild(i)) }

        parent.removeAllChildren()
        #expect(parent.children.isEmpty)

        // A second sweep over the now-empty container must be safe.
        parent.removeAllChildren()
        #expect(parent.children.isEmpty)
    }

    @Test func removeAllChildrenLeavesNonChildViewsUntouched() {
        let parent = makeParent()
        let children = (0..<3).map { makeChild($0) }
        for child in children { parent.addChildSafely(child) }

        // A plain, non-controller-owned subview added directly should survive,
        // because removeAllChildren only walks the `children` controllers.
        let overlay = UIView()
        parent.view.addSubview(overlay)
        #expect(parent.view.subviews.contains(overlay))

        parent.removeAllChildren()

        #expect(parent.children.isEmpty)
        #expect(children.allSatisfy { $0.parent == nil })
        // The standalone overlay remains attached.
        #expect(overlay.superview === parent.view)
        #expect(parent.view.subviews.contains(overlay))
    }

    @Test func removeAllChildrenRemovesEveryDistinctChildIdentity() {
        let parent = makeParent()
        let children = (0..<8).map { makeChild($0) }
        for child in children { parent.addChildSafely(child) }

        let identities = Set(children.map { ObjectIdentifier($0) })
        #expect(identities.count == 8)

        parent.removeAllChildren()

        let remaining = Set(parent.children.map { ObjectIdentifier($0) })
        #expect(remaining.isEmpty)
        #expect(children.allSatisfy { $0.parent == nil })
    }

    // MARK: - View-hierarchy interaction

    @Test func addAndRemoveWithinARealViewHierarchy() {
        let parent = makeParent()
        let window = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(parent.view)
        parent.view.frame = window.bounds

        let child = makeChild()
        parent.addChildSafely(child) { c, p in
            c.view.frame = p.view.bounds
        }
        parent.view.layoutIfNeeded()

        #expect(child.parent === parent)
        #expect(child.view.superview === parent.view)
        #expect(child.view.frame == parent.view.bounds)

        child.removeFromParentSafely()

        // Child leaves; the parent's own view stays in the window hierarchy.
        #expect(child.parent == nil)
        #expect(child.view.superview == nil)
        #expect(parent.view.superview === window)
    }

    // MARK: - Large data (time-bounded stress)

    @Test func removeAllChildrenHandlesLargeNumberOfChildren() {
        let parent = makeParent()
        let count = 1_000
        let children = (0..<count).map { makeChild($0) }
        for child in children {
            parent.addChildSafely(child)
        }
        #expect(parent.children.count == count)

        parent.removeAllChildren()

        #expect(parent.children.isEmpty)
        #expect(children.allSatisfy { $0.parent == nil })
        #expect(children.allSatisfy { $0.view.superview == nil })
    }

    // MARK: - Combined / sequence invariants

    @Test func repeatedAddRemoveCyclesKeepConsistentState() {
        let parent = makeParent()
        let child = makeChild()

        for _ in 0..<50 {
            parent.addChildSafely(child)
            #expect(child.parent === parent)
            #expect(parent.children.count == 1)
            #expect(child.view.superview === parent.view)

            child.removeFromParentSafely()
            #expect(child.parent == nil)
            #expect(parent.children.isEmpty)
            #expect(child.view.superview == nil)
        }
    }

    @Test func interleavedReparentAcrossTwoParentsKeepsSingleOwner() {
        let parentA = makeParent()
        let parentB = makeParent()
        let child = makeChild()

        for index in 0..<20 {
            let target = index.isMultiple(of: 2) ? parentA : parentB
            let other = index.isMultiple(of: 2) ? parentB : parentA

            target.addChildSafely(child)

            // The child has exactly one owner at any time; the other parent is empty.
            #expect(child.parent === target)
            #expect(target.children == [child])
            #expect(other.children.isEmpty)
            #expect(child.view.superview === target.view)
        }
    }
}
