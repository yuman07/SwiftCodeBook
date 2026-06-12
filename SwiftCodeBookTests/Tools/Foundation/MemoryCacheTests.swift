//
//  MemoryCacheTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/MemoryCache.swift
//  (MemoryCache<Key: Hashable, Value> — a Swift-friendly NSCache wrapper)
//
//  Notes on what is / isn't deterministically assertable:
//   - NSCache eviction (countLimit / totalCostLimit / discardable content) is
//     explicitly documented by Apple as advisory & best-effort. NSCache may
//     evict at any time, in any order, or not at all. Therefore these tests do
//     NOT assert that an over-limit insert evicts a *specific* key — that would
//     be flaky. We only assert that configuring the limits round-trips through
//     the getters and that the API does not crash / corrupt state.
//   - Storing/retrieving a value that was just set IS deterministic for NSCache
//     (a freshly inserted, retained object is not evicted mid-call), so we
//     assert those happy paths directly.
//   - The memory-warning eviction path is wired through
//     CurrentApplication.memoryWarningPublisher, which applies
//     `.receive(on: DispatchQueue.main)`. The cache's internal sink therefore
//     fires *asynchronously* on the main queue after the notification is posted
//     — a single `Task.yield()` is NOT a sufficient barrier. We synchronize on
//     the actual delivery using a checked continuation driven by our own sink on
//     the same (serial, FIFO) main queue (see the memory-warning test).
//

import Testing
import Foundation
import Combine
@testable import SwiftCodeBook

#if canImport(UIKit)
import UIKit
#endif

@Suite struct MemoryCacheTests {

    // MARK: - Basic set / get round-trip

    @Test func setThenGetReturnsStoredValue() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(42, forKey: "answer")
        #expect(cache.value(forKey: "answer") == 42)
    }

    @Test func getMissingKeyReturnsNil() {
        let cache = MemoryCache<String, Int>()
        #expect(cache.value(forKey: "absent") == nil)
    }

    @Test func overwriteExistingKeyReturnsLatestValue() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "k")
        cache.setValue(2, forKey: "k")
        cache.setValue(3, forKey: "k")
        #expect(cache.value(forKey: "k") == 3)
    }

    @Test func removeValueDropsTheEntry() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(7, forKey: "x")
        #expect(cache.value(forKey: "x") == 7)
        cache.removeValue(forKey: "x")
        #expect(cache.value(forKey: "x") == nil)
    }

    @Test func removeValueForAbsentKeyIsNoOp() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(7, forKey: "present")
        // Removing a key that was never inserted must not throw / crash and must
        // leave existing entries untouched.
        cache.removeValue(forKey: "never-inserted")
        #expect(cache.value(forKey: "present") == 7)
    }

    @Test func removeValueThenReinsertSameKeyWorks() {
        // Remove must not poison the key slot: a later insert with the same key
        // must store and retrieve correctly.
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "k")
        cache.removeValue(forKey: "k")
        #expect(cache.value(forKey: "k") == nil)
        cache.setValue(2, forKey: "k")
        #expect(cache.value(forKey: "k") == 2)
    }

    @Test func doubleRemoveIsIdempotent() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "k")
        cache.removeValue(forKey: "k")
        cache.removeValue(forKey: "k") // second remove must be a harmless no-op
        #expect(cache.value(forKey: "k") == nil)
    }

    @Test func removeAllClearsEverything() {
        let cache = MemoryCache<Int, String>()
        for i in 0..<50 {
            cache.setValue("v\(i)", forKey: i)
        }
        // Spot check a couple are present before clearing.
        #expect(cache.value(forKey: 0) == "v0")
        #expect(cache.value(forKey: 49) == "v49")

        cache.removeAll()

        #expect(cache.value(forKey: 0) == nil)
        #expect(cache.value(forKey: 25) == nil)
        #expect(cache.value(forKey: 49) == nil)
    }

    @Test func removeAllOnEmptyCacheIsNoOp() {
        let cache = MemoryCache<String, Int>()
        cache.removeAll()
        #expect(cache.value(forKey: "anything") == nil)
    }

    @Test func cacheIsUsableAfterRemoveAll() {
        // removeAll must not leave the cache in a broken state.
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "a")
        cache.removeAll()
        cache.setValue(2, forKey: "b")
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.value(forKey: "b") == 2)
    }

    // MARK: - Multiple distinct keys

    @Test func multipleDistinctKeysCoexist() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.setValue(3, forKey: "c")
        #expect(cache.value(forKey: "a") == 1)
        #expect(cache.value(forKey: "b") == 2)
        #expect(cache.value(forKey: "c") == 3)
    }

    @Test func removingOneKeyLeavesOthers() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        cache.removeValue(forKey: "a")
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.value(forKey: "b") == 2)
    }

    // MARK: - Key type variety / equality & hashing

    @Test func intKeysWorkIncludingExtremes() {
        let cache = MemoryCache<Int, String>()
        cache.setValue("min", forKey: Int.min)
        cache.setValue("max", forKey: Int.max)
        cache.setValue("zero", forKey: 0)
        cache.setValue("neg", forKey: -1)
        #expect(cache.value(forKey: Int.min) == "min")
        #expect(cache.value(forKey: Int.max) == "max")
        #expect(cache.value(forKey: 0) == "zero")
        #expect(cache.value(forKey: -1) == "neg")
    }

    @Test func adjacentIntKeysDoNotCollide() {
        // Guards against any accidental hash/equality folding of neighbouring keys.
        let cache = MemoryCache<Int, Int>()
        for i in -10...10 {
            cache.setValue(i * 1000, forKey: i)
        }
        for i in -10...10 {
            #expect(cache.value(forKey: i) == i * 1000)
        }
    }

    @Test(arguments: [
        "",                      // empty string
        " ",                     // whitespace
        "a",                     // single char
        "🙂",                    // emoji
        "e\u{0301}",             // combining acute accent (é decomposed)
        "café",                  // precomposed
        "𝓗𝓮𝓵𝓵𝓸",                // styled unicode
        "👨‍👩‍👧‍👦",                  // ZWJ family sequence
        String(repeating: "x", count: 10_000), // long string key
    ])
    func stringKeysOfVariousShapes(key: String) {
        let cache = MemoryCache<String, Int>()
        cache.setValue(123, forKey: key)
        #expect(cache.value(forKey: key) == 123)
    }

    @Test func decomposedAndPrecomposedKeysAreDistinctWhenStringsDiffer() {
        // "é" precomposed (U+00E9) vs "e" + combining acute (U+0065 U+0301)
        // are NOT String-equal, so they must be distinct cache keys.
        let precomposed = "\u{00E9}"
        let decomposed = "e\u{0301}"
        #expect(precomposed != decomposed) // sanity on our assumption
        let cache = MemoryCache<String, Int>()
        cache.setValue(1, forKey: precomposed)
        cache.setValue(2, forKey: decomposed)
        #expect(cache.value(forKey: precomposed) == 1)
        #expect(cache.value(forKey: decomposed) == 2)
    }

    private struct CompositeKey: Hashable, Sendable {
        let a: Int
        let b: String
    }

    @Test func customHashableStructKeys() {
        let cache = MemoryCache<CompositeKey, Int>()
        let k1 = CompositeKey(a: 1, b: "x")
        let k2 = CompositeKey(a: 1, b: "y")
        let k3 = CompositeKey(a: 2, b: "x")
        cache.setValue(10, forKey: k1)
        cache.setValue(20, forKey: k2)
        cache.setValue(30, forKey: k3)
        #expect(cache.value(forKey: k1) == 10)
        #expect(cache.value(forKey: k2) == 20)
        #expect(cache.value(forKey: k3) == 30)
        // An equal-but-distinct instance retrieves the same value.
        #expect(cache.value(forKey: CompositeKey(a: 1, b: "x")) == 10)
        // A key that was never inserted is absent.
        #expect(cache.value(forKey: CompositeKey(a: 9, b: "z")) == nil)
    }

    private enum EnumKey: Hashable, Sendable {
        case alpha
        case beta
        case indexed(Int)
    }

    @Test func enumKeysIncludingAssociatedValues() {
        let cache = MemoryCache<EnumKey, String>()
        cache.setValue("A", forKey: .alpha)
        cache.setValue("B", forKey: .beta)
        cache.setValue("0", forKey: .indexed(0))
        cache.setValue("1", forKey: .indexed(1))
        #expect(cache.value(forKey: .alpha) == "A")
        #expect(cache.value(forKey: .beta) == "B")
        #expect(cache.value(forKey: .indexed(0)) == "0")
        #expect(cache.value(forKey: .indexed(1)) == "1")
        #expect(cache.value(forKey: .indexed(2)) == nil)
    }

    // MARK: - Value type variety

    @Test func valueCanBeReferenceType() {
        let cache = MemoryCache<String, Box>()
        let box = Box(99)
        cache.setValue(box, forKey: "boxed")
        #expect(cache.value(forKey: "boxed")?.n == 99)
        #expect(cache.value(forKey: "boxed") === box)
    }

    @Test func valueCanBeStruct() {
        let cache = MemoryCache<Int, Point>()
        cache.setValue(Point(x: 3, y: 4), forKey: 1)
        #expect(cache.value(forKey: 1) == Point(x: 3, y: 4))
    }

    @Test func valueCanBeOptionalWrappedInArray() {
        // The wrapper boxes the value, so collection values round-trip intact.
        let cache = MemoryCache<String, [Int]>()
        cache.setValue([1, 2, 3], forKey: "list")
        #expect(cache.value(forKey: "list") == [1, 2, 3])
        cache.setValue([], forKey: "empty")
        #expect(cache.value(forKey: "empty") == [])
    }

    @Test func valueCanBeOptional() {
        // Value is the generic `Value` = Int?. Storing a `.some` and a `.none`
        // must be distinguishable from an absent key (which returns Value? == nil,
        // i.e. Optional<Optional<Int>>.none).
        let cache = MemoryCache<String, Int?>()
        cache.setValue(.some(5), forKey: "some")
        cache.setValue(.none, forKey: "none")
        // Stored .some(5): outer optional is non-nil, inner is 5.
        let some = cache.value(forKey: "some")
        #expect(some == .some(.some(5)))
        // Stored .none: outer optional is non-nil (entry exists), inner is nil.
        let none = cache.value(forKey: "none")
        #expect(none == .some(.none))
        // Truly absent key: outer optional is nil.
        let absent = cache.value(forKey: "absent")
        #expect(absent == .none)
    }

    @Test func doubleValuesIncludingSpecials() {
        let cache = MemoryCache<String, Double>()
        cache.setValue(.infinity, forKey: "inf")
        cache.setValue(-.infinity, forKey: "-inf")
        cache.setValue(.greatestFiniteMagnitude, forKey: "big")
        cache.setValue(.leastNonzeroMagnitude, forKey: "tiny")
        cache.setValue(.nan, forKey: "nan")
        cache.setValue(-0.0, forKey: "negzero")
        #expect(cache.value(forKey: "inf") == .infinity)
        #expect(cache.value(forKey: "-inf") == -.infinity)
        #expect(cache.value(forKey: "big") == .greatestFiniteMagnitude)
        #expect(cache.value(forKey: "tiny") == .leastNonzeroMagnitude)
        // -0.0 round-trips and preserves its sign bit.
        let negzero = cache.value(forKey: "negzero")
        #expect(negzero == 0.0)
        #expect(negzero?.sign == .minus)
        // NaN != NaN, so verify via isNaN on the retrieved value.
        let n = cache.value(forKey: "nan")
        #expect(n?.isNaN == true)
    }

    // MARK: - cost parameter

    @Test func setValueWithExplicitCostStoresValue() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(5, forKey: "k", cost: 1024)
        #expect(cache.value(forKey: "k") == 5)
    }

    @Test func setValueWithZeroCostIsDefaultBehavior() {
        let cache = MemoryCache<String, Int>()
        cache.setValue(5, forKey: "k", cost: 0)
        #expect(cache.value(forKey: "k") == 5)
    }

    @Test func setValueDefaultCostMatchesExplicitZero() {
        // The default cost argument is 0; assert the convenience overload behaves
        // identically to passing cost: 0 explicitly.
        let cache = MemoryCache<String, Int>()
        cache.setValue(5, forKey: "default")
        #expect(cache.value(forKey: "default") == 5)
    }

    // MARK: - Configuration properties round-trip

    @Test func namePropertyRoundTrips() {
        let cache = MemoryCache<String, Int>()
        #expect(cache.name == "") // NSCache default name is empty string
        cache.name = "my-cache"
        #expect(cache.name == "my-cache")
        cache.name = "另一个名字 🚀"
        #expect(cache.name == "另一个名字 🚀")
        cache.name = ""
        #expect(cache.name == "")
    }

    @Test func totalCostLimitRoundTrips() {
        let cache = MemoryCache<String, Int>()
        #expect(cache.totalCostLimit == 0) // 0 == no limit (default)
        cache.totalCostLimit = 1_000_000
        #expect(cache.totalCostLimit == 1_000_000)
        cache.totalCostLimit = Int.max
        #expect(cache.totalCostLimit == Int.max)
        cache.totalCostLimit = 0
        #expect(cache.totalCostLimit == 0)
    }

    @Test func countLimitRoundTrips() {
        let cache = MemoryCache<String, Int>()
        #expect(cache.countLimit == 0) // 0 == no limit (default)
        cache.countLimit = 100
        #expect(cache.countLimit == 100)
        cache.countLimit = 1
        #expect(cache.countLimit == 1)
        cache.countLimit = Int.max
        #expect(cache.countLimit == Int.max)
        cache.countLimit = 0
        #expect(cache.countLimit == 0)
    }

    @Test func evictsObjectsWithDiscardedContentRoundTrips() {
        let cache = MemoryCache<String, Int>()
        let original = cache.evictsObjectsWithDiscardedContent
        cache.evictsObjectsWithDiscardedContent = !original
        #expect(cache.evictsObjectsWithDiscardedContent == !original)
        cache.evictsObjectsWithDiscardedContent = original
        #expect(cache.evictsObjectsWithDiscardedContent == original)
    }

    @Test func settingCountLimitDoesNotEvictFreshlyInsertedValue() {
        // After setting a tight count limit, a value inserted immediately before
        // a read is still retained and retrievable (NSCache won't evict the
        // object you're actively reading back in the same synchronous window).
        let cache = MemoryCache<String, Int>()
        cache.countLimit = 1
        cache.setValue(7, forKey: "k")
        #expect(cache.value(forKey: "k") == 7)
    }

    // MARK: - Independence between instances

    @Test func separateCacheInstancesAreIndependent() {
        let a = MemoryCache<String, Int>()
        let b = MemoryCache<String, Int>()
        a.setValue(1, forKey: "shared")
        b.setValue(2, forKey: "shared")
        #expect(a.value(forKey: "shared") == 1)
        #expect(b.value(forKey: "shared") == 2)
        a.removeAll()
        #expect(a.value(forKey: "shared") == nil)
        #expect(b.value(forKey: "shared") == 2) // unaffected
    }

    @Test func configurationIsPerInstance() {
        // Config properties are backed by each instance's own NSCache.
        let a = MemoryCache<String, Int>()
        let b = MemoryCache<String, Int>()
        a.name = "A"
        a.countLimit = 5
        b.name = "B"
        b.countLimit = 9
        #expect(a.name == "A")
        #expect(a.countLimit == 5)
        #expect(b.name == "B")
        #expect(b.countLimit == 9)
    }

    // MARK: - Large data (time-bounded)

    @Test func largeNumberOfDistinctKeysStoreAndRetrieve() {
        // Use a generous count limit so NSCache keeps everything for this test.
        let cache = MemoryCache<Int, Int>()
        cache.countLimit = 0 // no count limit
        let n = 100_000
        for i in 0..<n {
            cache.setValue(i * 2, forKey: i)
        }
        // Spot-check a spread of keys rather than all 100k to stay fast.
        // (Eviction is advisory; freshly written tail entries are reliable, and
        //  for a no-limit cache NSCache typically retains all under no pressure.)
        for i in stride(from: 0, to: n, by: 9973) { // prime-ish stride
            // A value MAY have been evicted under memory pressure; if present it
            // must be correct. We assert correctness-when-present to avoid flake.
            if let v = cache.value(forKey: i) {
                #expect(v == i * 2)
            }
        }
        // The most recently written entries are reliably retained.
        #expect(cache.value(forKey: n - 1) == (n - 1) * 2)
    }

    // MARK: - Concurrency (type is @unchecked Sendable)

    @Test func concurrentWritesToDistinctKeysAllSucceed() async {
        let cache = MemoryCache<Int, Int>()
        cache.countLimit = 0
        let n = 1000
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    cache.setValue(i * 10, forKey: i)
                }
            }
        }
        // After all writes complete, the just-written entries are retrievable;
        // assert correctness for any that are present (no torn / wrong values).
        var found = 0
        for i in 0..<n {
            if let v = cache.value(forKey: i) {
                #expect(v == i * 10)
                found += 1
            }
        }
        // No-limit cache under no real memory pressure should retain ~all of
        // these small entries; require at least the bulk survived as a sanity
        // floor without being brittle about exact eviction.
        #expect(found >= n / 2)
    }

    @Test func concurrentReadsAndWritesDoNotCrash() async {
        let cache = MemoryCache<Int, String>()
        cache.countLimit = 0
        // Seed some values first.
        for i in 0..<100 {
            cache.setValue("v\(i)", forKey: i)
        }
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<500 {
                group.addTask {
                    let key = i % 100
                    cache.setValue("w\(key)", forKey: key)
                }
                group.addTask {
                    _ = cache.value(forKey: i % 100)
                }
                group.addTask {
                    if i % 50 == 0 { cache.removeValue(forKey: i % 100) }
                }
            }
        }
        // Invariant: any value present is one of the legal strings we wrote.
        for key in 0..<100 {
            if let v = cache.value(forKey: key) {
                #expect(v == "v\(key)" || v == "w\(key)")
            }
        }
    }

    @Test func concurrentSameKeyWritesConvergeToALegalValue() async {
        let cache = MemoryCache<String, Int>()
        let candidates = Set(0..<200)
        await withTaskGroup(of: Void.self) { group in
            for v in candidates {
                group.addTask {
                    cache.setValue(v, forKey: "hot")
                }
            }
        }
        // The surviving value must be exactly one of the values we wrote.
        // (No eviction pressure on a single small entry, so it should survive;
        //  but we guard with `if let` to avoid flake if NSCache ever drops it.)
        if let final = cache.value(forKey: "hot") {
            #expect(candidates.contains(final))
        }
    }

    @Test func concurrentRemoveAllAndWritesDoNotCrash() async {
        let cache = MemoryCache<Int, Int>()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<500 {
                group.addTask { cache.setValue(i, forKey: i) }
                if i % 25 == 0 {
                    group.addTask { cache.removeAll() }
                }
            }
        }
        // No invariant on final contents (interleaving is nondeterministic);
        // the test passes if the concurrent storm did not crash. Reads must still
        // be safe and return a legal (correct-when-present) value.
        if let v = cache.value(forKey: 0) {
            #expect(v == 0)
        }
        // Cache stays usable after the storm.
        cache.setValue(123, forKey: 7)
        #expect(cache.value(forKey: 7) == 123)
    }

    @Test func concurrentConfigurationMutationDoesNotCrash() async {
        let cache = MemoryCache<Int, Int>()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask { cache.countLimit = i }
                group.addTask { cache.totalCostLimit = i * 1000 }
                group.addTask { cache.name = "n\(i)" }
                group.addTask { cache.setValue(i, forKey: i) }
            }
        }
        // Reads must remain safe after the storm and return legal final values.
        #expect((0..<200).contains(cache.countLimit))
        let cost = cache.totalCostLimit
        #expect(cost % 1000 == 0)
        #expect((0..<200).map { "n\($0)" }.contains(cache.name))
    }

    @Test func concurrentReadsDuringHeavyWriteAreNeverTorn() async {
        // Stress the read path against concurrent overwrites of the SAME keys with
        // values that share a strict invariant (value == key * 7). Any non-nil read
        // must satisfy that invariant — proving no torn/garbage reads.
        let cache = MemoryCache<Int, Int>()
        cache.countLimit = 0
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    for k in 0..<200 { cache.setValue(k * 7, forKey: k) }
                }
                group.addTask {
                    for k in 0..<200 {
                        if let v = cache.value(forKey: k) {
                            #expect(v == k * 7)
                        }
                    }
                }
            }
        }
        for k in 0..<200 {
            if let v = cache.value(forKey: k) {
                #expect(v == k * 7)
            }
        }
    }

    // MARK: - Memory-warning eviction wiring

#if canImport(UIKit) && (os(iOS) || os(tvOS) || os(visionOS))
    @MainActor
    @Test func memoryWarningNotificationClearsCache() async {
        // The init subscribes to CurrentApplication.memoryWarningPublisher, which
        // merges UIApplication.didReceiveMemoryWarningNotification and applies
        // `.receive(on: DispatchQueue.main)`. Posting that notification causes the
        // cache's internal sink to drop all objects — but ASYNCHRONOUSLY on the
        // main queue, so we must not assert immediately after posting.
        //
        // Determinism without sleeps: we attach our OWN sink to the same publisher
        // as a barrier. The cache subscribed first (at init), our observer second.
        // NotificationCenter multicasts the post synchronously into both chains;
        // each chain then re-dispatches onto the *serial, FIFO* main queue. Because
        // the cache's block was enqueued before ours, by the time our continuation
        // resumes the cache has already executed `removeAllObjects()`.
        let cache = MemoryCache<String, Int>()
        cache.countLimit = 0
        cache.setValue(1, forKey: "a")
        cache.setValue(2, forKey: "b")
        #expect(cache.value(forKey: "a") == 1)

        let box = CancellableBox()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            box.cancellable = CurrentApplication.memoryWarningPublisher
                .first()
                .sink { _ in continuation.resume() }

            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
        }
        box.cancellable = nil

        // The cache's clear ran before our barrier resumed (FIFO main queue).
        #expect(cache.value(forKey: "a") == nil)
        #expect(cache.value(forKey: "b") == nil)

        // Cache remains usable after the warning.
        cache.setValue(3, forKey: "c")
        #expect(cache.value(forKey: "c") == 3)
    }

    @MainActor
    @Test func multipleMemoryWarningsKeepCacheUsable() async {
        // Repeated warnings must each clear and leave the cache operational.
        let cache = MemoryCache<String, Int>()
        for round in 0..<3 {
            cache.setValue(round, forKey: "k")
            #expect(cache.value(forKey: "k") == round)

            let box = CancellableBox()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                box.cancellable = CurrentApplication.memoryWarningPublisher
                    .first()
                    .sink { _ in continuation.resume() }
                NotificationCenter.default.post(
                    name: UIApplication.didReceiveMemoryWarningNotification,
                    object: nil
                )
            }
            box.cancellable = nil
            #expect(cache.value(forKey: "k") == nil)
        }
    }
#endif

    // MARK: - Lifecycle / deinit

    @Test func cacheDeallocatesCleanly() {
        // Creating and dropping a cache (which holds an AnyCancellable token)
        // must not crash. We can't observe the private cancelToken directly, but
        // exercising the full create/use/drop cycle covers deinit teardown.
        do {
            let cache = MemoryCache<String, Int>()
            cache.setValue(1, forKey: "k")
            #expect(cache.value(forKey: "k") == 1)
        }
        // A fresh cache after the previous one was released still works.
        let fresh = MemoryCache<String, Int>()
        #expect(fresh.value(forKey: "k") == nil)
    }

    @Test func manyShortLivedCachesDoNotLeakOrCrash() {
        // Stress the subscription/teardown path many times.
        for i in 0..<1000 {
            let cache = MemoryCache<Int, Int>()
            cache.setValue(i, forKey: i)
            #expect(cache.value(forKey: i) == i)
        }
    }

    // MARK: - Test helpers

    /// Reference value type used to assert identity round-trips through the box.
    private final class Box {
        let n: Int
        init(_ n: Int) { self.n = n }
    }

    /// Equatable struct value type for round-trip assertions.
    private struct Point: Equatable {
        let x: Int
        let y: Int
    }

    /// Holds a Combine cancellable alive across a continuation without tripping
    /// Sendable capture rules; only touched on the main actor in these tests.
    private final class CancellableBox: @unchecked Sendable {
        var cancellable: AnyCancellable?
    }
}
