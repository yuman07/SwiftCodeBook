//
//  CancelBagTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/Foundation/CancelBag.swift
//
//  CancelBag is a thread-safe (Sendable) container of AnyCancellable tokens
//  backed by an OSAllocatedUnfairLock. Public surface:
//    - init()
//    - store(_ cancelToken: AnyCancellable)
//    - cancelAll()           // cancels every stored token and clears the bag
//    - deinit                // drops all retained tokens (AnyCancellable cancels on dealloc)
//  plus an AnyCancellable.store(in: CancelBag) convenience extension.
//
//  Behavior is observed through AnyCancellable's documented contract: it invokes
//  its cancel closure exactly once, on either .cancel() OR deinit (whichever comes
//  first). The assertions below treat each token's "cancel happened" as a single
//  thread-safe counter increment, which is fully deterministic (not timing based):
//  no sleeps, no polling, no wall-clock dependencies.
//

import Combine
import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct CancelBagTests {

    // MARK: - Helpers

    /// A thread-safe counter usable from Sendable / nonisolated contexts.
    /// Nested + private so it never collides with identically named helpers in
    /// sibling test files compiled into the same module.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() {
            lock.lock(); defer { lock.unlock() }
            value += 1
        }
        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    /// Makes an AnyCancellable whose cancel side-effect increments `counter`.
    /// The returned value is the ONLY strong reference; callers decide who retains it.
    private static func makeToken(_ counter: Counter) -> AnyCancellable {
        AnyCancellable { counter.increment() }
    }

    // MARK: - Init

    @Test func initSucceeds() {
        let bag = CancelBag()
        // Nothing stored yet; cancelAll must be a no-op and must not crash.
        bag.cancelAll()
    }

    @Test func multipleIndependentBags() {
        let a = CancelBag()
        let b = CancelBag()
        let ca = Counter()
        let cb = Counter()
        a.store(Self.makeToken(ca))
        b.store(Self.makeToken(cb))

        a.cancelAll()
        #expect(ca.count == 1)
        // Cancelling a must not affect b.
        #expect(cb.count == 0)

        b.cancelAll()
        #expect(cb.count == 1)
    }

    // MARK: - store + cancelAll happy path

    @Test func storeThenCancelAllCancelsToken() {
        let bag = CancelBag()
        let counter = Counter()
        bag.store(Self.makeToken(counter))

        #expect(counter.count == 0)
        bag.cancelAll()
        #expect(counter.count == 1)
    }

    @Test(arguments: [0, 1, 2, 5, 50, 500])
    func cancelAllCancelsEveryStoredToken(tokenCount: Int) {
        let bag = CancelBag()
        let counter = Counter()
        for _ in 0..<tokenCount {
            bag.store(Self.makeToken(counter))
        }
        #expect(counter.count == 0)
        bag.cancelAll()
        #expect(counter.count == tokenCount)
        // Bag is drained: a follow-up cancelAll adds nothing.
        bag.cancelAll()
        #expect(counter.count == tokenCount)
    }

    @Test func cancelAllOnEmptyBagIsNoOp() {
        let bag = CancelBag()
        let counter = Counter()
        bag.cancelAll()
        bag.cancelAll()
        // Reaching here without crashing is the assertion; nothing was ever stored.
        #expect(counter.count == 0)
    }

    @Test func cancelAllClearsBagSoSecondCallDoesNothing() {
        let bag = CancelBag()
        let counter = Counter()
        bag.store(Self.makeToken(counter))
        bag.store(Self.makeToken(counter))

        bag.cancelAll()
        #expect(counter.count == 2)

        // cancelAll empties the bag via `defer { tokens.removeAll() }`, so the
        // second call has nothing left to cancel.
        bag.cancelAll()
        #expect(counter.count == 2)
    }

    @Test func storeAfterCancelAllStartsFresh() {
        let bag = CancelBag()
        let first = Counter()
        bag.store(Self.makeToken(first))
        bag.cancelAll()
        #expect(first.count == 1)

        // Bag is reusable: new tokens can be stored after cancelAll.
        let second = Counter()
        bag.store(Self.makeToken(second))
        #expect(second.count == 0)
        bag.cancelAll()
        #expect(second.count == 1)
        // The first counter must not be touched again by the second drain.
        #expect(first.count == 1)
    }

    @Test func interleavedStoreAndCancelAllRoundTrips() {
        // Several store/cancelAll cycles on one reused bag; each drain cancels only
        // the tokens stored since the previous drain.
        let bag = CancelBag()
        let counter = Counter()
        var expected = 0
        for batch in 1...5 {
            for _ in 0..<batch { bag.store(Self.makeToken(counter)) }
            expected += batch
            bag.cancelAll()
            #expect(counter.count == expected)
        }
        #expect(counter.count == 1 + 2 + 3 + 4 + 5)
    }

    // MARK: - Set dedup semantics

    @Test func storingSameTokenTwiceDeduplicates() {
        let bag = CancelBag()
        let counter = Counter()
        let token = Self.makeToken(counter)

        // The backing store is a Set<AnyCancellable> keyed by identity, so storing
        // the same instance twice keeps a single entry. AnyCancellable cancels at
        // most once regardless; this asserts no crash / double-cancel when re-storing
        // the same identity.
        bag.store(token)
        bag.store(token)

        bag.cancelAll()
        #expect(counter.count == 1)
    }

    @Test func distinctTokensAreNotDeduplicated() {
        // Two separate AnyCancellable instances wrapping the SAME counter must both
        // be retained and both cancelled (identity, not closure, is the Set key).
        let bag = CancelBag()
        let counter = Counter()
        bag.store(Self.makeToken(counter))
        bag.store(Self.makeToken(counter))
        bag.cancelAll()
        #expect(counter.count == 2)
    }

    // MARK: - AnyCancellable.store(in:) extension

    @Test func storeInExtensionRoutesToBag() {
        let bag = CancelBag()
        let counter = Counter()
        let token = Self.makeToken(counter)
        token.store(in: bag)

        #expect(counter.count == 0)
        bag.cancelAll()
        #expect(counter.count == 1)
    }

    @Test func storeInExtensionViaPublisherSink() {
        // Wire a real Combine pipeline and confirm the subscription's resources are
        // managed by the bag: cancelling unsubscribes (no further values delivered).
        let bag = CancelBag()
        let subject = PassthroughSubject<Int, Never>()
        let received = Counter()

        subject
            .sink { _ in received.increment() }
            .store(in: bag)

        subject.send(1)
        subject.send(2)
        #expect(received.count == 2)

        bag.cancelAll()

        // After cancellation the sink is torn down; further sends are ignored.
        subject.send(3)
        subject.send(4)
        #expect(received.count == 2)
    }

    @Test func storeInExtensionTornDownByBagDeinit() {
        // The sink is owned solely by the bag; when the bag deallocates the
        // subscription is torn down and later sends deliver nothing.
        let subject = PassthroughSubject<Int, Never>()
        let received = Counter()
        do {
            let bag = CancelBag()
            subject
                .sink { _ in received.increment() }
                .store(in: bag)
            subject.send(10)
            #expect(received.count == 1)
        }
        subject.send(20)
        #expect(received.count == 1)
    }

    // MARK: - deinit behavior

    @Test func deinitCancelsRetainedTokens() {
        let counter = Counter()
        do {
            let bag = CancelBag()
            // The token is a temporary owned only by the bag.
            bag.store(Self.makeToken(counter))
            #expect(counter.count == 0)
        }
        // When the bag deallocates it releases its sole retained reference to the
        // AnyCancellable, which then deallocates and fires its cancel closure exactly once.
        #expect(counter.count == 1)
    }

    @Test func deinitWithoutCancelAllStillReleasesAllTokens() {
        let counter = Counter()
        let n = 100
        do {
            let bag = CancelBag()
            for _ in 0..<n {
                bag.store(Self.makeToken(counter))
            }
            #expect(counter.count == 0)
        }
        #expect(counter.count == n)
    }

    @Test func deinitAfterCancelAllDoesNotDoubleCancel() {
        let counter = Counter()
        do {
            let bag = CancelBag()
            bag.store(Self.makeToken(counter))
            bag.cancelAll()
            #expect(counter.count == 1)
        }
        // cancelAll already removed the tokens from the bag, so deinit has nothing
        // to release; the closure must not be invoked a second time.
        #expect(counter.count == 1)
    }

    @Test func externallyRetainedTokenSurvivesBagDeinit() {
        let counter = Counter()
        // Keep a strong reference alive outside the bag's scope.
        let token = Self.makeToken(counter)
        do {
            let bag = CancelBag()
            bag.store(token)
        }
        // Bag is gone but the token is still retained here, so no cancel yet.
        #expect(counter.count == 0)
        token.cancel()
        #expect(counter.count == 1)
        // Explicit cancel + the (eventual) deinit of `token` must still total one.
        token.cancel()
        #expect(counter.count == 1)
    }

    @Test func cancelAllThenExternalCancelFiresOnceTotal() {
        // A token both stored in the bag and retained externally: cancelAll fires it,
        // and a later external .cancel() must be a no-op (AnyCancellable fires once).
        let bag = CancelBag()
        let counter = Counter()
        let token = Self.makeToken(counter)
        bag.store(token)
        bag.cancelAll()
        #expect(counter.count == 1)
        token.cancel()
        #expect(counter.count == 1)
    }

    // MARK: - Concurrency

    @Test func concurrentStoresThenCancelAllCancelsEverything() async {
        let bag = CancelBag()
        let counter = Counter()
        let total = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<total {
                group.addTask {
                    bag.store(Self.makeToken(counter))
                }
            }
        }

        // All tokens stored; none cancelled yet.
        #expect(counter.count == 0)
        bag.cancelAll()
        #expect(counter.count == total)
    }

    @Test func concurrentCancelAllIsSafeAndCancelsEachTokenOnce() async {
        let bag = CancelBag()
        let counter = Counter()
        let total = 500
        for _ in 0..<total {
            bag.store(Self.makeToken(counter))
        }

        // Many racing cancelAll calls; the unfair lock + atomic drain
        // (`defer { tokens.removeAll() }; return Array(tokens)`) guarantee exactly one
        // racer obtains the non-empty snapshot, so each token is cancelled exactly once
        // with no crash / double-cancel.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { bag.cancelAll() }
            }
        }

        #expect(counter.count == total)
    }

    @Test func concurrentStoreAndCancelAllDoesNotCrashAndCancelsAll() async {
        // Interleave stores with cancelAll calls. Invariant after the dust settles:
        // every produced token's cancel closure ran exactly once, whether via a racing
        // cancelAll, the final cancelAll, or bag deinit. So total cancels == stores.
        let counter = Counter()
        let producers = 200
        do {
            let bag = CancelBag()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<producers {
                    group.addTask {
                        bag.store(Self.makeToken(counter))
                    }
                }
                for _ in 0..<50 {
                    group.addTask {
                        bag.cancelAll()
                    }
                }
            }
            bag.cancelAll()
        }
        // After every task finished and the bag deallocated, all closures have fired.
        #expect(counter.count == producers)
    }

    @Test func storeFromManyTasksSharedBagPreservesAllTokens() async {
        // Stress the lock with concurrent inserts of distinct tokens and verify none
        // are lost (Set keyed by identity; all instances are distinct).
        let bag = CancelBag()
        let counter = Counter()
        let total = 2000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<total {
                group.addTask {
                    let token = Self.makeToken(counter)
                    token.store(in: bag)
                }
            }
        }

        bag.cancelAll()
        #expect(counter.count == total)
    }

    @Test func concurrentStoresViaExtensionThenDeinitCancelsAll() async {
        // Concurrent inserts via the store(in:) extension, then let the bag deinit
        // (no explicit cancelAll) drain everything.
        let counter = Counter()
        let total = 1000
        do {
            let bag = CancelBag()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<total {
                    group.addTask {
                        Self.makeToken(counter).store(in: bag)
                    }
                }
            }
            #expect(counter.count == 0)
        }
        #expect(counter.count == total)
    }

    // MARK: - Sendable / capture across isolation

    @Test func bagIsUsableAcrossDetachedTasks() async {
        let bag = CancelBag()
        let counter = Counter()

        // CancelBag is declared Sendable; it must be safe to capture in a detached task.
        await Task.detached {
            bag.store(Self.makeToken(counter))
        }.value

        bag.cancelAll()
        #expect(counter.count == 1)
    }
}
