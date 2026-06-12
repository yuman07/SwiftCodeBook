//
//  WeakObjectTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/Foundation/WeakObject.swift
//
//  Source under test:
//      public final class WeakObject<T: AnyObject> {
//          public weak let value: T?
//          public init(_ value: T) { self.value = value }
//      }
//
//  WeakObject is a generic wrapper that holds a *weak* reference to a class
//  instance. While at least one strong reference to the wrapped object exists
//  elsewhere, `value` returns that object; once the last strong reference is
//  released, `value` automatically becomes nil.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct WeakObjectTests {

    // MARK: - Test fixtures (private, nested to avoid module-wide collisions)

    /// A plain reference type with identity and a payload.
    private final class Box {
        let id: Int
        init(id: Int) { self.id = id }
    }

    /// A reference type that records its own deallocation via a callback.
    /// `onDeinit` is captured at construction time.
    private final class TrackingObject {
        let onDeinit: () -> Void
        init(onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
        deinit { onDeinit() }
    }

    /// An NSObject subclass to exercise class-hierarchy / Foundation behaviour.
    private final class SubBox: NSObject {
        let tag: String
        init(tag: String) { self.tag = tag }
    }

    // MARK: - Happy path: value is reachable while strongly held

    @Test func valueReturnsWrappedObjectWhileStronglyHeld() {
        let object = Box(id: 7)
        let weakRef = WeakObject(object)
        // The local `object` keeps a strong reference alive.
        #expect(weakRef.value === object)
        #expect(weakRef.value?.id == 7)
        // Keep `object` alive past the assertions.
        withExtendedLifetime(object) {}
    }

    @Test func valueIsSameIdentityAcrossMultipleReads() {
        let object = Box(id: 1)
        let weakRef = WeakObject(object)
        let first = weakRef.value
        let second = weakRef.value
        #expect(first === second)
        #expect(first === object)
        withExtendedLifetime(object) {}
    }

    @Test func initStoresExactInstanceNotACopy() throws {
        let object = Box(id: 99)
        let weakRef = WeakObject(object)
        // Identity, not equality: must be the very same instance.
        #expect(weakRef.value === object)
        // ObjectIdentifier round-trip confirms same allocation.
        let stored = try #require(weakRef.value)
        #expect(ObjectIdentifier(stored) == ObjectIdentifier(object))
        withExtendedLifetime(object) {}
    }

    // MARK: - Boundary payloads (min / max / zero / negative / unicode / empty)

    @Test(arguments: [Int.min, -1, 0, 1, Int.max])
    func payloadBoundariesRoundTripExactly(value: Int) throws {
        let object = Box(id: value)
        let weakRef = WeakObject(object)
        let stored = try #require(weakRef.value)
        // No truncation / no overflow: exact Int payload survives wrapping.
        #expect(stored.id == value)
        #expect(stored === object)
        withExtendedLifetime(object) {}
    }

    @Test(arguments: ["", "hello", "🧨💥🇨🇳", "a\u{0301}", "line\nbreak\t\0null"])
    func stringPayloadBoundariesRoundTripExactly(tag: String) throws {
        let object = SubBox(tag: tag)
        let weakRef = WeakObject(object)
        let stored = try #require(weakRef.value)
        // Empty, multi-scalar emoji, combining marks, control chars all preserved.
        #expect(stored.tag == tag)
        #expect(stored.tag.unicodeScalars.count == tag.unicodeScalars.count)
        withExtendedLifetime(object) {}
    }

    // MARK: - Weak semantics: value becomes nil after last strong ref released

    @Test func valueBecomesNilAfterStrongReferenceReleased() {
        let weakRef: WeakObject<Box>
        do {
            let object = Box(id: 42)
            weakRef = WeakObject(object)
            #expect(weakRef.value != nil)
            #expect(weakRef.value?.id == 42)
        } // `object` deallocates here: only WeakObject held a weak ref.
        #expect(weakRef.value == nil)
        // Optional-chaining through a zeroed weak must short-circuit to nil.
        #expect(weakRef.value?.id == nil)
    }

    @Test func wrappedObjectIsActuallyDeallocated() async {
        // Exactly one deinit must fire while still inside the confirmation body.
        await confirmation("wrapped object deinits when no strong refs remain", expectedCount: 1) { confirm in
            let weakRef: WeakObject<TrackingObject>
            do {
                let object = TrackingObject(onDeinit: { confirm() })
                weakRef = WeakObject(object)
                #expect(weakRef.value != nil)
            } // object should deinit at end of this scope.
            // After the strong ref is gone, the weak value must be nil.
            #expect(weakRef.value == nil)
        }
    }

    @Test func weakObjectDoesNotRetainAndDoesNotDelayDeinit() {
        var deinited = false
        let weakRef: WeakObject<TrackingObject>
        do {
            let object = TrackingObject(onDeinit: { deinited = true })
            weakRef = WeakObject(object)
            #expect(deinited == false)        // alive while strongly held
            #expect(weakRef.value === object)
        }
        // The WeakObject wrapper itself is still alive, but it must not retain.
        #expect(deinited == true)
        #expect(weakRef.value == nil)
    }

    @Test func weakObjectStaysNonNilWhileAnyStrongRefExists() {
        let object = Box(id: 5)
        let weakRef = WeakObject(object)
        #expect(weakRef.value != nil)

        var mutableHolder: Box? = object
        // Even with two strong refs (object + mutableHolder), value lives.
        #expect(weakRef.value != nil)
        #expect(mutableHolder != nil)
        mutableHolder = nil
        // Dropping ONE of two strong refs must not zero the weak value.
        #expect(weakRef.value != nil)
        #expect(weakRef.value === object)
        withExtendedLifetime(object) {}
    }

    // MARK: - Generic instantiation over different class kinds

    @Test func worksWithNSObjectSubclass() {
        let sub = SubBox(tag: "hello")
        let weakRef = WeakObject(sub)
        #expect(weakRef.value === sub)
        #expect(weakRef.value?.tag == "hello")
        withExtendedLifetime(sub) {}
    }

    @Test func worksWithFoundationNSObject() {
        let obj = NSObject()
        let weakRef = WeakObject(obj)
        #expect(weakRef.value === obj)
        withExtendedLifetime(obj) {}
    }

    @Test func declaredAsBaseTypeStillHoldsConcreteInstance() {
        // Wrap a subclass but observe through the NSObject static type.
        let sub = SubBox(tag: "base")
        let weakRef: WeakObject<NSObject> = WeakObject(sub)
        #expect(weakRef.value === sub)
        #expect((weakRef.value as? SubBox)?.tag == "base")
        withExtendedLifetime(sub) {}
    }

    @Test func baseTypedWrapperFailsDowncastForUnrelatedConcreteType() {
        // A plain NSObject wrapped as WeakObject<NSObject> is NOT a SubBox:
        // the downcast must fail (return nil) rather than crash or succeed.
        let obj = NSObject()
        let weakRef: WeakObject<NSObject> = WeakObject(obj)
        #expect(weakRef.value === obj)
        #expect(weakRef.value as? SubBox == nil)
        withExtendedLifetime(obj) {}
    }

    @Test func nsObjectValueBecomesNilAfterRelease() {
        let weakRef: WeakObject<NSObject>
        do {
            let obj = NSObject()
            weakRef = WeakObject(obj)
            #expect(weakRef.value != nil)
        }
        #expect(weakRef.value == nil)
    }

    // MARK: - Multiple wrappers around the same instance

    @Test func multipleWrappersShareSameTargetAndAllNilTogether() {
        let wrappers: [WeakObject<Box>]
        do {
            let object = Box(id: 314)
            wrappers = (0..<5).map { _ in WeakObject(object) }
            // All wrappers see the identical instance while held.
            for w in wrappers {
                #expect(w.value === object)
                #expect(w.value?.id == 314)
            }
        }
        // After release, every wrapper independently observes nil.
        for w in wrappers {
            #expect(w.value == nil)
        }
    }

    // MARK: - Collections of WeakObject

    @Test func arrayOfWeakObjectsTracksLiveAndDeadEntries() {
        // Keep even-id objects strongly alive; let odd-id objects die.
        var strong: [Box] = []
        let weaks: [WeakObject<Box>] = (0..<10).map { i in
            let box = Box(id: i)
            if i % 2 == 0 { strong.append(box) }
            return WeakObject(box)
        }
        // Odd-id boxes have no remaining strong refs -> their value is nil.
        for (i, w) in weaks.enumerated() {
            if i % 2 == 0 {
                #expect(w.value != nil)
                #expect(w.value?.id == i)
            } else {
                #expect(w.value == nil)
            }
        }
        // Sanity: we kept exactly the even ones.
        #expect(strong.count == 5)
        #expect(strong.map(\.id) == [0, 2, 4, 6, 8])
        withExtendedLifetime(strong) {}
    }

    @Test func compactingLiveValuesFromWeakArray() {
        var strong: [Box] = []
        var weaks: [WeakObject<Box>] = []
        for i in 0..<6 {
            let box = Box(id: i)
            if i < 3 { strong.append(box) } // keep first three alive
            weaks.append(WeakObject(box))
        }
        let liveIDs = weaks.compactMap { $0.value?.id }.sorted()
        #expect(liveIDs == [0, 1, 2])
        // The dead half must contribute nothing to the compacted result.
        #expect(weaks.compactMap { $0.value }.count == 3)
        withExtendedLifetime(strong) {}
    }

    // MARK: - Large data / stress (time-bounded)

    @Test func largeNumberOfWrappersAllResolveWhileHeld() {
        let count = 100_000
        // Strongly hold every object so all weak values stay non-nil.
        let objects = (0..<count).map { Box(id: $0) }
        let weaks = objects.map { WeakObject($0) }
        var nonNil = 0
        var checksum = 0
        for w in weaks {
            if let v = w.value {
                nonNil += 1
                checksum &+= v.id
            }
        }
        #expect(nonNil == count)
        // Sum of 0..<count = count*(count-1)/2.
        #expect(checksum == count * (count - 1) / 2)
        withExtendedLifetime(objects) {}
    }

    @Test func largeNumberOfWrappersAllNilWhenTargetsReleased() {
        let count = 50_000
        let weaks: [WeakObject<Box>] = {
            // All targets die at the end of this closure.
            let objects = (0..<count).map { Box(id: $0) }
            let ws = objects.map { WeakObject($0) }
            // Confirm they are alive inside the scope.
            #expect(ws.first?.value != nil)
            #expect(ws.last?.value != nil)
            withExtendedLifetime(objects) {}
            return ws
        }()
        let liveCount = weaks.reduce(into: 0) { $0 += ($1.value != nil ? 1 : 0) }
        #expect(liveCount == 0)
    }

    // MARK: - Concurrency
    //
    // `WeakObject` is a non-Sendable reference type (a class with a stored
    // weak property, not marked Sendable), and the wrapped `Box` is also
    // non-Sendable. Under Swift 6 strict concurrency we therefore must NOT
    // capture a shared wrapper or a shared object into a non-isolated
    // `@Sendable` task closure. The first two tests have each child task
    // construct its own object + wrapper entirely inside the task and return
    // only Sendable scalars. This still hammers WeakObject's init + value read
    // concurrently and asserts the invariant under contention.

    @Test func concurrentConstructAndReadWhileLocallyHeld() async {
        let taskCount = 1000
        let okCount: Int = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    // Object + wrapper are created and read locally; nothing
                    // non-Sendable crosses the task boundary.
                    let object = Box(id: i)
                    let wrapper = WeakObject(object)
                    guard let v = wrapper.value else { return false }
                    let sameIdentity = ObjectIdentifier(v) == ObjectIdentifier(object)
                    let samePayload = v.id == i
                    withExtendedLifetime(object) {}
                    return sameIdentity && samePayload
                }
            }
            var total = 0
            for await ok in group where ok { total += 1 }
            return total
        }
        // Every task must have observed a live, correct value.
        #expect(okCount == taskCount)
    }

    @Test func concurrentWrapperBecomesNilAfterLocalReleaseInTask() async {
        let taskCount = 500
        // Each task creates an object, wraps it, releases it, and reports
        // whether the weak value correctly dropped to nil. Result is Sendable.
        let niledOutCount: Int = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<taskCount {
                group.addTask {
                    let wrapper: WeakObject<Box>
                    do {
                        let object = Box(id: i)
                        wrapper = WeakObject(object)
                        guard wrapper.value != nil else { return false }
                    } // object released here
                    return wrapper.value == nil
                }
            }
            var count = 0
            for await result in group where result { count += 1 }
            return count
        }
        // Every single task must have observed nil after its local release.
        #expect(niledOutCount == taskCount)
    }

    @MainActor
    @Test func mainActorSharedWrapperManyConcurrentReads() async {
        // Legitimately share ONE wrapper instance: confine everything to the
        // main actor. The test is @MainActor-isolated, and each reader Task is
        // `@MainActor`-isolated too, so capturing the non-Sendable `wrapper`
        // is sound (same isolation domain) and reads are serialized. This
        // exercises many overlapping reads of a single shared WeakObject.
        let object = Box(id: 4242)
        let wrapper = WeakObject(object)
        let expected = ObjectIdentifier(object)

        var tasks: [Task<Bool, Never>] = []
        for _ in 0..<200 {
            let task = Task { @MainActor in
                guard let v = wrapper.value else { return false }
                return ObjectIdentifier(v) == expected
            }
            tasks.append(task)
        }

        var okCount = 0
        for task in tasks where await task.value { okCount += 1 }
        #expect(okCount == 200)
        withExtendedLifetime(object) {}
    }

    // MARK: - Combined behaviour / round-trip-ish

    @Test func setThenGetThenReleaseLifecycle() {
        // "set" via init, "get" via value, then release and "get" again.
        var deinitCount = 0
        let weakRef: WeakObject<TrackingObject>
        do {
            let object = TrackingObject(onDeinit: { deinitCount += 1 })
            weakRef = WeakObject(object)        // set
            #expect(weakRef.value === object)   // get (alive)
            #expect(deinitCount == 0)
        }                                       // release
        #expect(weakRef.value == nil)           // get (dead)
        #expect(deinitCount == 1)
    }
}
