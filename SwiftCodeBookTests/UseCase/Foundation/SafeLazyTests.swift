//
//  SafeLazyTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/UseCase/Foundation/SafeLazy.swift
//
//  Internal surface under test (visible via @testable):
//    - final class SafeLazy
//        - init()
//        - var readOnlyObj: NSObject  { get }            // lazy, thread-safe, read-only
//        - var readWriteObj: NSObject { get set }        // lazy, thread-safe, read-write
//
//  The backing OSAllocatedUnfairLock<NSObject?> properties are `private`, so they are
//  exercised only indirectly through the `readOnlyObj` / `readWriteObj` surface.
//
//  Concurrency model note: `SafeLazy` is NOT Sendable. To hammer it across tasks we
//  wrap a single shared instance in a small `@unchecked Sendable` box; the type's own
//  internal locking is precisely what we are validating, so the box adds no synthetic
//  synchronization of its own beyond holding the reference.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct SafeLazyTests {

    // MARK: - Test helpers (private, nested to avoid module-wide name collisions)

    /// Minimal `@unchecked Sendable` wrapper so a single `SafeLazy` instance can be
    /// shared into task groups. We rely on `SafeLazy`'s own internal locking, which is
    /// the thing under test.
    private struct Box: @unchecked Sendable {
        let value: SafeLazy
        init(_ value: SafeLazy) { self.value = value }
    }

    /// `@unchecked Sendable` wrapper for an array of pre-created candidate objects that
    /// concurrent writers will store. Only ever read by index, never mutated.
    private struct CandidateBox: @unchecked Sendable {
        let objs: [NSObject]
        init(_ objs: [NSObject]) { self.objs = objs }
    }

    /// Thread-safe collector of object identities observed concurrently.
    private final class IdentitySink: @unchecked Sendable {
        private let lock = NSLock()
        private var _ids: [ObjectIdentifier] = []

        func add(_ obj: NSObject) {
            let id = ObjectIdentifier(obj)
            lock.lock()
            _ids.append(id)
            lock.unlock()
        }

        var ids: [ObjectIdentifier] {
            lock.lock()
            defer { lock.unlock() }
            return _ids
        }
    }

    /// Test-only `NSObject` subclass with a stored property, to confirm subclass
    /// instances round-trip through `readWriteObj` without slicing identity.
    private final class TaggedObject: NSObject {
        let tag: Int
        init(tag: Int) { self.tag = tag }
    }

    // MARK: - init

    @Test
    func initSucceeds() {
        let sut = SafeLazy()
        // Construction must not crash; the lazy slots are reachable immediately after.
        #expect(type(of: sut.readOnlyObj) == NSObject.self)
        #expect(type(of: sut.readWriteObj) == NSObject.self)
    }

    @Test
    func multipleInitsProduceDistinctInstances() {
        let a = SafeLazy()
        let b = SafeLazy()
        #expect(a !== b)
    }

    // MARK: - readOnlyObj: basic lazy behavior

    @Test
    func readOnlyObjReturnsNonNilNSObject() {
        let sut = SafeLazy()
        let obj = sut.readOnlyObj
        // Exact dynamic type: the lazy path constructs a plain NSObject, not a subclass.
        #expect(type(of: obj) == NSObject.self)
    }

    @Test
    func readOnlyObjIsStableAcrossReads() {
        let sut = SafeLazy()
        let first = sut.readOnlyObj
        let second = sut.readOnlyObj
        let third = sut.readOnlyObj
        // Lazy init must produce exactly one instance, reused on every subsequent read.
        #expect(first === second)
        #expect(second === third)
    }

    @Test
    func readOnlyObjIsStableAcrossManyReads() {
        let sut = SafeLazy()
        let first = sut.readOnlyObj
        // Hammer the get path repeatedly; identity must never drift.
        for _ in 0..<10_000 {
            #expect(sut.readOnlyObj === first)
        }
    }

    @Test
    func readOnlyObjInstancesAreIndependentPerSafeLazy() {
        let a = SafeLazy()
        let b = SafeLazy()
        // Each SafeLazy owns its own backing storage.
        #expect(a.readOnlyObj !== b.readOnlyObj)
    }

    @Test
    func readOnlyAndReadWriteAreSeparateSlots() {
        let sut = SafeLazy()
        // The two lazy properties are backed by distinct locks/storage.
        #expect(sut.readOnlyObj !== sut.readWriteObj)
    }

    @Test
    func readOnlyObjFirstReadingReadWriteFirstStillIndependent() {
        // Order of first touch must not couple the two slots.
        let sut = SafeLazy()
        let rw = sut.readWriteObj
        let ro = sut.readOnlyObj
        #expect(ro !== rw)
        // And both remain stable afterwards.
        #expect(sut.readWriteObj === rw)
        #expect(sut.readOnlyObj === ro)
    }

    // MARK: - readWriteObj: lazy get

    @Test
    func readWriteObjLazyGetReturnsNonNilNSObject() {
        let sut = SafeLazy()
        let obj = sut.readWriteObj
        #expect(type(of: obj) == NSObject.self)
    }

    @Test
    func readWriteObjLazyGetIsStableAcrossReads() {
        let sut = SafeLazy()
        let first = sut.readWriteObj
        let second = sut.readWriteObj
        // Without any set, repeated gets reuse the single lazily-created instance.
        #expect(first === second)
    }

    @Test
    func readWriteObjLazyGetIsStableAcrossManyReads() {
        let sut = SafeLazy()
        let first = sut.readWriteObj
        for _ in 0..<10_000 {
            #expect(sut.readWriteObj === first)
        }
    }

    // MARK: - readWriteObj: set / get round-trip

    @Test
    func readWriteObjSetThenGetReturnsSameInstance() {
        let sut = SafeLazy()
        let custom = NSObject()
        sut.readWriteObj = custom
        #expect(sut.readWriteObj === custom)
        // Idempotent read.
        #expect(sut.readWriteObj === custom)
    }

    @Test
    func readWriteObjSetBeforeAnyGetWins() {
        let sut = SafeLazy()
        let custom = NSObject()
        // Setting before the lazy get should short-circuit lazy creation entirely.
        sut.readWriteObj = custom
        #expect(sut.readWriteObj === custom)
    }

    @Test
    func readWriteObjLastSetWins() {
        let sut = SafeLazy()
        let first = NSObject()
        let second = NSObject()
        sut.readWriteObj = first
        #expect(sut.readWriteObj === first)
        sut.readWriteObj = second
        #expect(sut.readWriteObj === second)
        #expect(sut.readWriteObj !== first)
    }

    @Test
    func readWriteObjManySequentialSetsLeaveLast() {
        let sut = SafeLazy()
        let objs = (0..<256).map { _ in NSObject() }
        for o in objs {
            sut.readWriteObj = o
        }
        #expect(sut.readWriteObj === objs.last)
    }

    @Test
    func readWriteObjOverwritesLazilyCreatedValue() {
        let sut = SafeLazy()
        // Force the lazy creation first...
        let lazyCreated = sut.readWriteObj
        let replacement = NSObject()
        // ...then overwrite it.
        sut.readWriteObj = replacement
        #expect(sut.readWriteObj === replacement)
        #expect(sut.readWriteObj !== lazyCreated)
    }

    @Test
    func readWriteObjCanStoreSubclassInstance() {
        // The setter accepts any NSObject; a subclass instance must round-trip identically.
        let sut = SafeLazy()
        let custom = TaggedObject(tag: 42)
        sut.readWriteObj = custom
        let got = sut.readWriteObj
        #expect(got === custom)
        let downcast = got as? TaggedObject
        #expect(downcast?.tag == 42)
    }

    @Test
    func readWriteObjSetTheSameInstanceTwiceIsStable() {
        let sut = SafeLazy()
        let custom = NSObject()
        sut.readWriteObj = custom
        sut.readWriteObj = custom
        #expect(sut.readWriteObj === custom)
    }

    @Test
    func settingReadWriteDoesNotAffectReadOnly() {
        let sut = SafeLazy()
        let roBefore = sut.readOnlyObj
        let replacement = NSObject()
        sut.readWriteObj = replacement
        // readOnlyObj must be untouched by readWriteObj mutations.
        #expect(sut.readOnlyObj === roBefore)
        #expect(sut.readOnlyObj !== replacement)
    }

    @Test
    func settingReadWriteOnOneInstanceDoesNotAffectAnother() {
        let a = SafeLazy()
        let b = SafeLazy()
        let custom = NSObject()
        a.readWriteObj = custom
        // b must lazily create its own, never observe a's stored value.
        #expect(b.readWriteObj !== custom)
        #expect(type(of: b.readWriteObj) == NSObject.self)
    }

    // MARK: - Concurrency: readOnlyObj must yield a single shared instance

    @Test
    func readOnlyObjConcurrentReadsConvergeToSingleInstance() async {
        let box = Box(SafeLazy())
        let sink = IdentitySink()
        let count = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    sink.add(box.value.readOnlyObj)
                }
            }
        }

        let ids = sink.ids
        #expect(ids.count == count)
        // All concurrent readers must observe the exact same lazily-created object.
        #expect(Set(ids).count == 1)
        // And a final synchronous read must agree with what was observed.
        let final = ObjectIdentifier(box.value.readOnlyObj)
        #expect(Set(ids) == [final])
    }

    // MARK: - Concurrency: readWriteObj first-get race must also converge

    @Test
    func readWriteObjConcurrentLazyGetsConvergeToSingleInstance() async {
        let box = Box(SafeLazy())
        let sink = IdentitySink()
        let count = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    sink.add(box.value.readWriteObj)
                }
            }
        }

        let ids = sink.ids
        #expect(ids.count == count)
        // No set is performed, so the lazy-get race must still collapse to one object.
        #expect(Set(ids).count == 1)
        // The single observed object must match a final synchronous read.
        let final = ObjectIdentifier(box.value.readWriteObj)
        #expect(Set(ids) == [final])
    }

    // MARK: - Concurrency: many concurrent reads after a known set all see that set value

    @Test
    func readWriteObjConcurrentReadsAfterSetAllSeeSetValue() async {
        let box = Box(SafeLazy())
        let known = NSObject()
        let knownId = ObjectIdentifier(known)
        // Establish the value before launching readers.
        box.value.readWriteObj = known

        let sink = IdentitySink()
        let count = 1000
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask { sink.add(box.value.readWriteObj) }
            }
        }

        let ids = sink.ids
        #expect(ids.count == count)
        // Every concurrent reader must observe exactly the previously-set object; the
        // lazy-create path must never fire once a value is present.
        #expect(Set(ids) == [knownId])
    }

    // MARK: - Concurrency: concurrent set then a final read sees one of the set values

    @Test
    func readWriteObjConcurrentSetsLeaveOneOfTheWrittenValues() async {
        let box = Box(SafeLazy())
        let count = 500

        // Pre-create candidate objects and record their identities.
        let candidates = (0..<count).map { _ in NSObject() }
        let candidateIds = Set(candidates.map { ObjectIdentifier($0) })
        let cbox = CandidateBox(candidates)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    box.value.readWriteObj = cbox.objs[i]
                }
            }
        }

        // After all writers complete, the stored value must be exactly one of the
        // written candidates (no torn / nil / spuriously-lazy-created object).
        let finalId = ObjectIdentifier(box.value.readWriteObj)
        #expect(candidateIds.contains(finalId))
        // Repeated reads remain stable post-races.
        #expect(ObjectIdentifier(box.value.readWriteObj) == finalId)
    }

    // MARK: - Concurrency: a deterministic final set after a race must win

    @Test
    func readWriteObjDeterministicSetAfterRaceWins() async {
        let box = Box(SafeLazy())
        let count = 500
        let candidates = (0..<count).map { _ in NSObject() }
        let cbox = CandidateBox(candidates)

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask { box.value.readWriteObj = cbox.objs[i] }
            }
        }

        // A single, happens-after-all-writers set turns last-write-wins into a hard,
        // non-flaky equality: this winner is deterministic.
        let winner = NSObject()
        box.value.readWriteObj = winner
        #expect(box.value.readWriteObj === winner)
        // And it must not be one of the raced candidates.
        let candidateIds = Set(candidates.map { ObjectIdentifier($0) })
        #expect(!candidateIds.contains(ObjectIdentifier(box.value.readWriteObj)))
    }

    // MARK: - Concurrency: mixed readers + writers must not crash and stay self-consistent

    @Test
    func readWriteObjConcurrentMixedReadWriteStaysConsistent() async {
        let box = Box(SafeLazy())
        let writeCount = 300
        let candidates = (0..<writeCount).map { _ in NSObject() }
        let candidateIds = Set(candidates.map { ObjectIdentifier($0) })
        let cbox = CandidateBox(candidates)

        // Concurrent readers observe whatever the lock yields; we just require that
        // every observation is type-correct and non-trapping.
        let readSink = IdentitySink()

        await withTaskGroup(of: Void.self) { group in
            // Writers.
            for i in 0..<writeCount {
                group.addTask {
                    box.value.readWriteObj = cbox.objs[i]
                }
            }
            // Concurrent readers — must never crash or trap; they record what they saw.
            for _ in 0..<writeCount {
                group.addTask {
                    readSink.add(box.value.readWriteObj)
                }
            }
        }

        // Every reader produced exactly one observation (no reader was dropped/trapped).
        #expect(readSink.ids.count == writeCount)
        // Final state must be one of the written candidates (a writer always wins over
        // the lazy-create path once any set has happened).
        let finalId = ObjectIdentifier(box.value.readWriteObj)
        #expect(candidateIds.contains(finalId))
    }

    // MARK: - Concurrency: subclass identity is preserved under set/read races

    @Test
    func readWriteObjConcurrentSubclassSetsPreserveSubclassIdentity() async {
        let box = Box(SafeLazy())
        let count = 200
        let candidates = (0..<count).map { TaggedObject(tag: $0) }
        let cbox = CandidateBox(candidates)
        let tagsByIdentity = Dictionary(
            uniqueKeysWithValues: candidates.map { (ObjectIdentifier($0), $0.tag) }
        )

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask { box.value.readWriteObj = cbox.objs[i] }
            }
        }

        let stored = box.value.readWriteObj
        // The winner must be one of the subclass instances, with its tag intact (no
        // slicing to a bare NSObject and no nil).
        let typed = stored as? TaggedObject
        #expect(typed != nil)
        #expect(tagsByIdentity[ObjectIdentifier(stored)] == typed?.tag)
    }

    // MARK: - Concurrency: independent properties don't interfere under load

    @Test
    func bothPropertiesConcurrentlyAccessedRemainIndependent() async {
        let box = Box(SafeLazy())
        let roSink = IdentitySink()
        let count = 500

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask { roSink.add(box.value.readOnlyObj) }
                group.addTask { _ = box.value.readWriteObj }
            }
        }

        let roIds = roSink.ids
        #expect(roIds.count == count)
        // readOnlyObj remains a single stable instance regardless of readWriteObj traffic.
        #expect(Set(roIds).count == 1)
        // The two slots are still distinct after concurrent load.
        #expect(box.value.readOnlyObj !== box.value.readWriteObj)
    }

    // MARK: - Many independent instances (light load / correctness at scale)

    @Test
    func manyInstancesEachHaveDistinctReadOnlyObjects() {
        let n = 1000
        let lazies = (0..<n).map { _ in SafeLazy() }
        let ids = lazies.map { ObjectIdentifier($0.readOnlyObj) }
        // Every instance must own a unique lazily-created object.
        #expect(Set(ids).count == n)
    }

    @Test
    func manyInstancesConcurrentReadOnlyReadsAllDistinct() async {
        let n = 1000
        let boxes = (0..<n).map { _ in Box(SafeLazy()) }
        // CandidateBox can hold the boxes too via a private sendable carrier.
        struct Boxes: @unchecked Sendable {
            let items: [Box]
            init(_ items: [Box]) { self.items = items }
        }
        let carrier = Boxes(boxes)

        let sink = IdentitySink()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask { sink.add(carrier.items[i].value.readOnlyObj) }
            }
        }

        let ids = sink.ids
        #expect(ids.count == n)
        // Even under concurrent first-touch across distinct instances, each lazy slot
        // produces a unique object.
        #expect(Set(ids).count == n)
    }
}
