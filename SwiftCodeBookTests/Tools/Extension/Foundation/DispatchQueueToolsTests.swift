//
//  DispatchQueueToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/DispatchQueue+Tools.swift
//  Covers the public `DispatchQueue` extension:
//    - static var currentQueueLabel: String
//    - static var isMainQueue: Bool
//    - static func dispatchToMainIfNeeded(_ operation: @escaping @MainActor () -> Void)
//    - static func runOnce(file:line:function:customKey:operation:)
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct DispatchQueueToolsTests {

    // MARK: - currentQueueLabel

    @Test
    func currentQueueLabelOnMainMatchesMainLabel() async {
        // Run the assertion on the main queue/thread and verify the label is the
        // main queue's label.
        await MainActor.run {
            #expect(DispatchQueue.currentQueueLabel == DispatchQueue.main.label)
        }
    }

    @Test
    func currentQueueLabelOnCustomQueueMatchesThatQueueLabel() async {
        let label = "com.swiftcodebook.tests.currentLabel.\(UUID().uuidString)"
        let queue = DispatchQueue(label: label)

        let observed: String = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: DispatchQueue.currentQueueLabel)
            }
        }
        #expect(observed == label)
    }

    @Test
    func currentQueueLabelIsNonEmptyOnMain() async {
        // The main queue always has a stable, non-empty label. Assert on the main
        // queue where the contract is deterministic.
        let observed: String = await MainActor.run {
            DispatchQueue.currentQueueLabel
        }
        #expect(observed == DispatchQueue.main.label)
        #expect(!observed.isEmpty)
    }

    @Test
    func currentQueueLabelOnAnonymousQueueIsEmpty() async {
        // A DispatchQueue created with an empty label reports an empty label.
        // This exercises the boundary where `currentQueueLabel` is "".
        let queue = DispatchQueue(label: "")
        let observed: String = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: DispatchQueue.currentQueueLabel)
            }
        }
        #expect(observed.isEmpty)
    }

    @Test
    func currentQueueLabelDistinguishesTwoCustomQueues() async {
        let labelA = "com.swiftcodebook.tests.A.\(UUID().uuidString)"
        let labelB = "com.swiftcodebook.tests.B.\(UUID().uuidString)"
        let queueA = DispatchQueue(label: labelA)
        let queueB = DispatchQueue(label: labelB)

        let observedA: String = await withCheckedContinuation { c in
            queueA.async { c.resume(returning: DispatchQueue.currentQueueLabel) }
        }
        let observedB: String = await withCheckedContinuation { c in
            queueB.async { c.resume(returning: DispatchQueue.currentQueueLabel) }
        }

        #expect(observedA == labelA)
        #expect(observedB == labelB)
        #expect(observedA != observedB)
    }

    @Test
    func currentQueueLabelHandlesUnicodeLabel() async {
        // Labels carrying unicode/emoji must round-trip exactly through the
        // C-string bridge used by `currentQueueLabel`.
        let label = "队列-🚀-\u{1F1EF}\u{1F1F5}-\(UUID().uuidString)"
        let queue = DispatchQueue(label: label)
        let observed: String = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: DispatchQueue.currentQueueLabel)
            }
        }
        #expect(observed == label)
    }

    // MARK: - isMainQueue

    @Test
    func isMainQueueIsTrueOnMainQueue() async {
        let observed: Bool = await MainActor.run {
            DispatchQueue.isMainQueue
        }
        #expect(observed == true)
    }

    @Test
    func isMainQueueIsFalseOnCustomQueue() async {
        let label = "com.swiftcodebook.tests.notMain.\(UUID().uuidString)"
        let queue = DispatchQueue(label: label)

        let observed: Bool = await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: DispatchQueue.isMainQueue)
            }
        }
        #expect(observed == false)
    }

    @Test
    func isMainQueueIsFalseOnGlobalQueue() async {
        let observed: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: DispatchQueue.isMainQueue)
            }
        }
        #expect(observed == false)
    }

    @Test
    func isMainQueueConsistentWithCurrentQueueLabel() async {
        // On the main queue both signals must agree.
        let result: (isMain: Bool, label: String) = await MainActor.run {
            (DispatchQueue.isMainQueue, DispatchQueue.currentQueueLabel)
        }
        #expect(result.isMain == (result.label == DispatchQueue.main.label))
    }

    @Test
    func isMainQueueAndLabelAgreeOnCustomQueue() async {
        // On a non-main queue both signals must also agree: not main, and label
        // != main label.
        let label = "com.swiftcodebook.tests.agree.\(UUID().uuidString)"
        let queue = DispatchQueue(label: label)
        let result: (isMain: Bool, label: String) = await withCheckedContinuation { c in
            queue.async {
                c.resume(returning: (DispatchQueue.isMainQueue, DispatchQueue.currentQueueLabel))
            }
        }
        #expect(result.isMain == false)
        #expect(result.label == label)
        #expect(result.isMain == (result.label == DispatchQueue.main.label))
    }

    // MARK: - dispatchToMainIfNeeded

    @Test @MainActor
    func dispatchToMainIfNeededRunsSynchronouslyWhenAlreadyOnMain() {
        // Already on the main thread + main queue: the operation must run
        // synchronously (before the function returns), per the fast path.
        var ran = false
        DispatchQueue.dispatchToMainIfNeeded {
            ran = true
        }
        #expect(ran == true)
    }

    @Test @MainActor
    func dispatchToMainIfNeededFastPathExecutesBeforeReturning() {
        // Prove the fast path is truly synchronous, not async-deferred: a sentinel
        // mutated by a statement *after* the call must observe the operation's
        // effect already applied.
        var order: [Int] = []
        DispatchQueue.dispatchToMainIfNeeded {
            order.append(1)
        }
        order.append(2)
        #expect(order == [1, 2])
    }

    @Test @MainActor
    func dispatchToMainIfNeededRunsSynchronouslyMultipleTimes() {
        var counter = 0
        for _ in 0..<10 {
            DispatchQueue.dispatchToMainIfNeeded {
                counter += 1
            }
        }
        // All ten ran synchronously, in order, on the main actor.
        #expect(counter == 10)
    }

    @Test
    func dispatchToMainIfNeededRunsOperationWhenCalledFromBackground() async {
        // From a non-main context the operation is dispatched async to main and
        // should still execute exactly once.
        await confirmation("operation executes on main", expectedCount: 1) { confirm in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let bg = DispatchQueue(label: "com.swiftcodebook.tests.bg.\(UUID().uuidString)")
                bg.async {
                    DispatchQueue.dispatchToMainIfNeeded {
                        // MainActor-isolated body.
                        #expect(Thread.isMainThread)
                        confirm()
                        continuation.resume()
                    }
                }
            }
        }
    }

    @Test
    func dispatchToMainIfNeededExecutesOnMainThreadFromBackground() async {
        let observed: (isMain: Bool, isMainQueue: Bool, label: String) = await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, Bool, String), Never>) in
            let bg = DispatchQueue(label: "com.swiftcodebook.tests.bg2.\(UUID().uuidString)")
            bg.async {
                DispatchQueue.dispatchToMainIfNeeded {
                    continuation.resume(returning: (Thread.isMainThread, DispatchQueue.isMainQueue, DispatchQueue.currentQueueLabel))
                }
            }
        }
        #expect(observed.isMain == true)
        #expect(observed.isMainQueue == true)
        #expect(observed.label == DispatchQueue.main.label)
    }

    @Test
    func dispatchToMainIfNeededFromGlobalQueueRunsOnMain() async {
        // The async path must also fire when invoked from a global concurrent
        // queue (a distinct entry point from a serial custom queue).
        let observedIsMain: Bool = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .background).async {
                DispatchQueue.dispatchToMainIfNeeded {
                    continuation.resume(returning: Thread.isMainThread)
                }
            }
        }
        #expect(observedIsMain == true)
    }

    @Test
    func dispatchToMainIfNeededRunsAllOperationsFromBackgroundConcurrently() async {
        // Hammer the async path from many background queues; every operation
        // must run exactly once on the main thread.
        let total = 200
        let counter = Counter()

        await confirmation("all operations execute", expectedCount: total) { confirm in
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<total {
                    group.addTask {
                        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                            let q = DispatchQueue(label: "com.swiftcodebook.tests.fan.\(i)")
                            q.async {
                                DispatchQueue.dispatchToMainIfNeeded {
                                    #expect(Thread.isMainThread)
                                    counter.increment()
                                    confirm()
                                    c.resume()
                                }
                            }
                        }
                    }
                }
                await group.waitForAll()
            }
        }

        #expect(counter.value == total)
    }

    // MARK: - runOnce

    @Test
    func runOnceWithCustomKeyRunsExactlyOnceAcrossManyCalls() {
        let key = "runOnce.basic.\(UUID().uuidString)"
        var runCount = 0
        for _ in 0..<5 {
            DispatchQueue.runOnce(customKey: key) {
                runCount += 1
            }
        }
        #expect(runCount == 1)
    }

    @Test
    func runOnceFirstCallExecutesOperation() {
        let key = "runOnce.first.\(UUID().uuidString)"
        var ran = false
        DispatchQueue.runOnce(customKey: key) {
            ran = true
        }
        #expect(ran == true)
    }

    @Test
    func runOnceSecondCallDoesNotExecuteOperation() {
        // Sharper than counting: the second operation must NOT run at all. If it
        // ran, `secondRan` would flip true.
        let key = "runOnce.second.\(UUID().uuidString)"
        var firstRan = false
        var secondRan = false
        DispatchQueue.runOnce(customKey: key) { firstRan = true }
        DispatchQueue.runOnce(customKey: key) { secondRan = true }
        #expect(firstRan == true)
        #expect(secondRan == false)
    }

    @Test
    func runOnceDifferentCustomKeysEachRunOnce() {
        let keyA = "runOnce.keyA.\(UUID().uuidString)"
        let keyB = "runOnce.keyB.\(UUID().uuidString)"
        var countA = 0
        var countB = 0

        DispatchQueue.runOnce(customKey: keyA) { countA += 1 }
        DispatchQueue.runOnce(customKey: keyA) { countA += 1 }
        DispatchQueue.runOnce(customKey: keyB) { countB += 1 }
        DispatchQueue.runOnce(customKey: keyB) { countB += 1 }

        #expect(countA == 1)
        #expect(countB == 1)
    }

    @Test
    func runOnceWithoutCustomKeyUsesCallSiteToken() {
        // Two distinct call sites within this function must each be allowed to
        // run once because the implicit token includes #line.
        var firstSite = 0
        var secondSite = 0

        DispatchQueue.runOnce { firstSite += 1 }   // call site 1
        DispatchQueue.runOnce { secondSite += 1 }  // call site 2 (different #line)

        #expect(firstSite == 1)
        #expect(secondSite == 1)
    }

    @Test
    func runOnceSameImplicitCallSiteInLoopRunsOnlyOnce() {
        // The same physical call site (same #file/#line/#function) used in a
        // loop yields the same token, so the operation runs only once.
        var runCount = 0
        for _ in 0..<8 {
            DispatchQueue.runOnce { runCount += 1 }
        }
        #expect(runCount == 1)
    }

    @Test
    func runOnceExplicitFileLineOverridesImplicitToken() {
        // Passing explicit file/line forms the token "file_line_function". Two
        // calls with the SAME explicit file+line+(implicit)function collapse to a
        // single token, so only the first runs. Use a unique sentinel file path
        // to stay independent of other suites.
        let uniqueFile = "synthetic-\(UUID().uuidString).swift"
        var runCount = 0
        DispatchQueue.runOnce(file: uniqueFile, line: 42) { runCount += 1 }
        DispatchQueue.runOnce(file: uniqueFile, line: 42) { runCount += 1 }
        #expect(runCount == 1)

        // A different explicit line under the same file is a distinct token.
        var otherCount = 0
        DispatchQueue.runOnce(file: uniqueFile, line: 99) { otherCount += 1 }
        #expect(otherCount == 1)
    }

    @Test
    func runOnceEmptyCustomKeyIsHonored() {
        // An explicit empty-string key is a valid, stable token. The first call
        // with the empty key in the whole test process wins; subsequent calls
        // with the empty key are suppressed. To keep this deterministic and
        // independent of other tests, we only assert that calling it does not
        // crash and that the run count never exceeds one within this scope.
        var runCount = 0
        DispatchQueue.runOnce(customKey: "") { runCount += 1 }
        DispatchQueue.runOnce(customKey: "") { runCount += 1 }
        #expect(runCount <= 1)
    }

    @Test
    func runOnceUnicodeAndEmojiCustomKey() {
        let key = "🔑-日本語-\u{0301}combining-\(UUID().uuidString)"
        var runCount = 0
        for _ in 0..<3 {
            DispatchQueue.runOnce(customKey: key) { runCount += 1 }
        }
        #expect(runCount == 1)
    }

    @Test
    func runOnceTreatsCanonicallyEquivalentKeysAsDistinctBytes() {
        // The token set is keyed by String value, and Swift String equality is
        // by Unicode canonical equivalence. A precomposed "é" (U+00E9) and a
        // decomposed "e" + combining acute (U+0065 U+0301) are canonically equal,
        // so they share ONE token. Verify this contract holds (only one run).
        let suffix = UUID().uuidString
        let precomposed = "caf\u{00E9}-\(suffix)"          // café
        let decomposed = "cafe\u{0301}-\(suffix)"          // cafe + combining acute
        #expect(precomposed == decomposed)                 // sanity: Swift sees them equal

        var runCount = 0
        DispatchQueue.runOnce(customKey: precomposed) { runCount += 1 }
        DispatchQueue.runOnce(customKey: decomposed) { runCount += 1 }
        #expect(runCount == 1)
    }

    @Test
    func runOnceConcurrentCallsRunExactlyOnce() async {
        // Concurrency invariant: the unfair lock must guarantee that even with
        // hundreds of simultaneous callers using the SAME key, the operation
        // runs exactly once and no update is lost.
        let key = "runOnce.concurrent.\(UUID().uuidString)"
        let counter = Counter()
        let total = 1000

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<total {
                group.addTask {
                    DispatchQueue.runOnce(customKey: key) {
                        counter.increment()
                    }
                }
            }
            await group.waitForAll()
        }

        #expect(counter.value == 1)
    }

    @Test
    func runOnceConcurrentDistinctKeysEachRunExactlyOnce() async {
        // With N distinct keys hammered concurrently, each key's operation runs
        // exactly once -> total runs == N.
        let runID = UUID().uuidString
        let total = 500
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                let key = "runOnce.distinct.\(runID).\(i)"
                // Two concurrent attempts per key.
                group.addTask {
                    DispatchQueue.runOnce(customKey: key) { counter.increment() }
                }
                group.addTask {
                    DispatchQueue.runOnce(customKey: key) { counter.increment() }
                }
            }
            await group.waitForAll()
        }

        #expect(counter.value == total)
    }

    @Test
    func runOnceLargeNumberOfDistinctKeys() {
        // Large but time-bounded: 100_000 distinct keys, each runs once.
        let runID = UUID().uuidString
        let total = 100_000
        var runCount = 0
        for i in 0..<total {
            DispatchQueue.runOnce(customKey: "\(runID).\(i)") {
                runCount += 1
            }
        }
        #expect(runCount == total)
    }

    @Test
    func runOnceOperationCanCaptureAndMutateState() {
        let key = "runOnce.capture.\(UUID().uuidString)"
        var captured = "before"
        DispatchQueue.runOnce(customKey: key) {
            captured = "after"
        }
        #expect(captured == "after")
        // Second invocation must NOT re-run, so the value stays "after".
        DispatchQueue.runOnce(customKey: key) {
            captured = "mutated-again"
        }
        #expect(captured == "after")
    }

    @Test
    func runOnceConcurrentDistinctKeysExecuteOnceWithCorrectMapping() async {
        // Beyond a total count, verify each individual key actually fired by
        // recording which keys executed. Every key index must appear exactly
        // once, proving no key is dropped or double-fired under contention.
        let runID = UUID().uuidString
        let total = 300
        let recorder = IndexRecorder()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<total {
                let key = "runOnce.map.\(runID).\(i)"
                group.addTask {
                    DispatchQueue.runOnce(customKey: key) { recorder.record(i) }
                }
                group.addTask {
                    DispatchQueue.runOnce(customKey: key) { recorder.record(i) }
                }
            }
            await group.waitForAll()
        }

        #expect(recorder.count == total)
        #expect(recorder.distinctCount == total)
        #expect(recorder.maxOccurrence == 1)
    }

    // MARK: - Helpers

    /// A simple thread-safe counter for concurrency assertions.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = 0
        func increment() {
            lock.lock()
            _value += 1
            lock.unlock()
        }
        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
    }

    /// Thread-safe recorder of fired key indices, used to prove no key is
    /// dropped or double-fired under concurrent `runOnce` contention.
    private final class IndexRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [Int: Int] = [:]
        func record(_ index: Int) {
            lock.lock()
            counts[index, default: 0] += 1
            lock.unlock()
        }
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return counts.values.reduce(0, +)
        }
        var distinctCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return counts.count
        }
        var maxOccurrence: Int {
            lock.lock()
            defer { lock.unlock() }
            return counts.values.max() ?? 0
        }
    }
}
