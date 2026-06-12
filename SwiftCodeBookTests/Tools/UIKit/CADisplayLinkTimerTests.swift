//
//  CADisplayLinkTimerTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/UIKit/CADisplayLinkTimer.swift
//
//  Exercises the @MainActor `CADisplayLinkTimer`:
//    - init(preferredFrameRateRange:block:) with and without a frame-rate range
//    - start() / stop() lifecycle, idempotency, and re-start behavior
//    - the callback block: first delivery is elapsedTime == 0, subsequent
//      deliveries are non-negative, finite, and monotonically non-decreasing
//    - stop() actually halts further callbacks
//    - deinit-driven teardown (no crash when an unstopped timer is released)
//
//  The CADisplayLink is added to the main run loop in `.common` mode, so its
//  callbacks fire on the main actor while the main run loop is being serviced.
//  The whole suite is @MainActor. To drive the link deterministically without
//  Task.sleep polling we repeatedly hop through the main run loop via tiny
//  `DispatchQueue.main.asyncAfter` continuations (the same proven pattern used by
//  the sibling CADisplayLinkAnimator tests). Real assertions are gated on a
//  `confirmation` / target-count that finishes the await early once enough ticks
//  arrive, and the iteration budget is bounded so the test always terminates even
//  if the simulator never services the link. Every started timer is stopped
//  synchronously before the helper returns, so no timer leaks ticks into a later
//  test.
//

import Testing
import Foundation
import QuartzCore
@testable import SwiftCodeBook

@Suite @MainActor struct CADisplayLinkTimerTests {

    // Upper bound on run-loop hops while waiting for callbacks. Each hop is a
    // ~1ms main-queue deadline, so 800 hops is roughly an 0.8s+ wall-clock cap on
    // a quiet machine — generous headroom for a 60/120Hz link (~16-33ms/frame)
    // while still guaranteeing termination if the link never fires.
    private static let maxSpinIterations = 800

    // MARK: - Run-loop driver

    /// Yields control back to the main run loop once so an attached CADisplayLink
    /// can deliver a frame. Suspends on a continuation resumed by a tiny
    /// `DispatchQueue.main.asyncAfter`; no Task.sleep polling.
    private static func hopMainRunLoop() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                cont.resume()
            }
        }
    }

    /// Spins the main run loop up to `maxSpinIterations` hops, stopping early as
    /// soon as `predicate()` returns true. Returns whether the predicate was
    /// satisfied within the budget.
    @discardableResult
    private static func spinUntil(_ predicate: () -> Bool) async -> Bool {
        if predicate() { return true }
        for _ in 0 ..< maxSpinIterations {
            await hopMainRunLoop()
            if predicate() { return true }
        }
        return false
    }

    // MARK: - Helpers

    /// Starts a fresh timer, spins the run loop until at least `n` callback
    /// elapsed-time values have been delivered (or the budget is exhausted), then
    /// stops the timer synchronously before returning. Returns the collected
    /// values in delivery order. The timer is guaranteed stopped on return, so it
    /// cannot leak ticks into subsequent tests.
    private func collectElapsedTimes(
        count n: Int,
        preferredFrameRateRange: CAFrameRateRange? = nil
    ) async -> [TimeInterval] {
        let collector = ElapsedCollector()
        let timer = CADisplayLinkTimer(preferredFrameRateRange: preferredFrameRateRange) { elapsed in
            collector.record(elapsed)
        }
        timer.start()
        await Self.spinUntil { collector.values.count >= n }
        timer.stop()
        return collector.values
    }

    // MARK: - Initialization

    @Test
    func initWithDefaultsSucceeds() {
        let timer = CADisplayLinkTimer { _ in }
        // No start yet: constructing and immediately releasing must be safe.
        _ = timer
    }

    @Test
    func initWithNilFrameRateRangeSucceeds() {
        let timer = CADisplayLinkTimer(preferredFrameRateRange: nil) { _ in }
        _ = timer
    }

    @Test
    func initWithExplicitFrameRateRangeSucceeds() {
        let range = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        let timer = CADisplayLinkTimer(preferredFrameRateRange: range) { _ in }
        _ = timer
    }

    @Test
    func initWithDefaultFrameRateRangeSucceeds() {
        let timer = CADisplayLinkTimer(preferredFrameRateRange: .default) { _ in }
        _ = timer
    }

    @Test
    func initDoesNotInvokeBlockEagerly() async {
        // Construction must not fire the block; only start() + a serviced run loop
        // does. Spin a few hops to be sure nothing sneaks a callback in.
        let collector = ElapsedCollector()
        let timer = CADisplayLinkTimer { collector.record($0) }
        for _ in 0 ..< 5 { await Self.hopMainRunLoop() }
        #expect(collector.values.isEmpty)
        timer.stop()
    }

    // MARK: - stop() without start()

    @Test
    func stopBeforeStartIsHarmless() {
        let timer = CADisplayLinkTimer { _ in }
        // Calling stop on a never-started timer must not crash and must be a no-op.
        timer.stop()
        timer.stop()
    }

    @Test
    func multipleStopsAreIdempotent() {
        let timer = CADisplayLinkTimer { _ in }
        timer.start()
        timer.stop()
        timer.stop()
        timer.stop()
    }

    // MARK: - start()/stop() lifecycle without observing callbacks

    @Test
    func startThenStopDoesNotCrash() {
        let timer = CADisplayLinkTimer { _ in }
        timer.start()
        timer.stop()
    }

    @Test
    func startCalledTwiceRecreatesLinkWithoutCrash() {
        // start() internally calls stop() first, so a second start must replace
        // the prior display link cleanly.
        let timer = CADisplayLinkTimer { _ in }
        timer.start()
        timer.start()
        timer.stop()
    }

    @Test
    func restartAfterStopDoesNotCrash() {
        let timer = CADisplayLinkTimer { _ in }
        timer.start()
        timer.stop()
        timer.start()
        timer.stop()
    }

    @Test
    func manyStartStopCyclesAreStable() {
        let timer = CADisplayLinkTimer { _ in }
        for _ in 0 ..< 100 {
            timer.start()
            timer.stop()
        }
        // Final state must be stopped; a trailing start/stop must still be clean.
        timer.start()
        timer.stop()
    }

    @Test
    func manyConsecutiveStartsWithoutStopRecreateLinkCleanly() {
        // Each start() invalidates the previous link before creating a new one;
        // hammering start() must never crash or leak an active link beyond the
        // final stop().
        let timer = CADisplayLinkTimer { _ in }
        for _ in 0 ..< 100 {
            timer.start()
        }
        timer.stop()
    }

    // MARK: - deinit teardown

    @Test
    func deinitOfUnstoppedTimerDoesNotCrash() async {
        // Releasing a started-but-not-stopped timer must invalidate the link via
        // deinit -> stop() without crashing.
        do {
            let timer = CADisplayLinkTimer { _ in }
            timer.start()
            // timer goes out of scope here and is deallocated.
            _ = timer
        }
        // Spin a little so any lingering run-loop source from the released link is
        // drained; the suite must remain healthy afterwards.
        for _ in 0 ..< 5 { await Self.hopMainRunLoop() }
    }

    @Test
    func deinitOfNeverStartedTimerDoesNotCrash() {
        do {
            let timer = CADisplayLinkTimer { _ in }
            _ = timer
        }
    }

    @Test
    func deinitDoesNotFireBlockAfterRelease() async {
        // After the only strong reference is dropped, deinit -> stop() invalidates
        // the link; no further callbacks may be delivered into our collector.
        let collector = ElapsedCollector()
        do {
            let timer = CADisplayLinkTimer { collector.record($0) }
            timer.start()
            _ = timer
        }
        let countAtRelease = collector.values.count
        for _ in 0 ..< 30 { await Self.hopMainRunLoop() }
        #expect(collector.values.count == countAtRelease)
    }

    // MARK: - Callback delivery semantics

    @Test
    func firstCallbackDeliversZeroElapsedTime() async throws {
        let values = await collectElapsedTimes(count: 1)
        // The link must have fired at least once within the budget.
        try #require(!values.isEmpty)
        let first = try #require(values.first)
        // The implementation seeds startTimestamp on the first tick and emits 0.
        #expect(first == 0)
    }

    @Test
    func multipleCallbacksAreDelivered() async throws {
        // Ask for a handful of ticks; the link should deliver them on the run loop.
        let values = await collectElapsedTimes(count: 5)
        try #require(!values.isEmpty)
        // At least two confirms the link fired repeatedly rather than just once.
        #expect(values.count >= 2)
    }

    @Test
    func elapsedTimesAreMonotonicallyNonDecreasing() async throws {
        let values = await collectElapsedTimes(count: 6)
        try #require(values.count >= 2)
        // Each elapsed value is measured from the same start timestamp, so the
        // sequence must be non-decreasing.
        for i in 1 ..< values.count {
            #expect(values[i] >= values[i - 1])
        }
    }

    @Test
    func laterElapsedTimeExceedsTheZeroBaseline() async throws {
        // The first value is exactly 0. After several real frames have elapsed the
        // final value must be strictly greater than 0. We assert on the LAST value
        // (not every later value) because two display-link callbacks can in theory
        // share a timestamp, which would make a strict ">0 for all" check flaky.
        let values = await collectElapsedTimes(count: 4)
        try #require(values.count >= 2)
        #expect(values.first == 0)
        let last = try #require(values.last)
        #expect(last > 0)
    }

    @Test
    func elapsedTimesAreFiniteAndNonNegative() async throws {
        let values = await collectElapsedTimes(count: 4)
        try #require(!values.isEmpty)
        for value in values {
            #expect(value.isFinite)
            #expect(!value.isNaN)
            #expect(value >= 0)
        }
    }

    @Test
    func elapsedTimeIsRelativeNotAbsoluteUptime() async throws {
        // elapsedTime is the delta from the first tick's timestamp, not an absolute
        // CFTimeInterval since boot (which would be a huge number). A few frames
        // must stay tiny; the spin budget caps wall-clock at well under a second,
        // so any value over a couple seconds means an absolute timestamp leaked.
        let values = await collectElapsedTimes(count: 3)
        try #require(!values.isEmpty)
        let last = try #require(values.last)
        #expect(last < 5)
    }

    // MARK: - start() with a preferred frame-rate range still fires

    @Test
    func timerWithExplicitFrameRateRangeStillFires() async throws {
        let range = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        let values = await collectElapsedTimes(count: 2, preferredFrameRateRange: range)
        try #require(!values.isEmpty)
        #expect(values.first == 0)
    }

    @Test
    func timerWithDefaultFrameRateRangeStillFires() async throws {
        let values = await collectElapsedTimes(count: 2, preferredFrameRateRange: .default)
        try #require(!values.isEmpty)
        #expect(values.first == 0)
    }

    // MARK: - stop() halts callbacks

    @Test
    func stopHaltsFurtherCallbacks() async throws {
        // Start a timer, observe at least one tick, stop it, then verify no further
        // callbacks arrive within a bounded window.
        let counter = TickCounter()
        let timer = CADisplayLinkTimer { _ in counter.increment() }
        timer.start()

        let fired = await Self.spinUntil { counter.value >= 1 }
        try #require(fired)

        timer.stop()
        let countAtStop = counter.value

        // Give the run loop ample time to (not) deliver more ticks.
        for _ in 0 ..< 60 { await Self.hopMainRunLoop() }

        // After stop(), the tick count must not have grown.
        #expect(counter.value == countAtStop)
    }

    @Test
    func restartResetsElapsedBaseline() async throws {
        // After a full stop/start cycle, startTimestamp is reset to nil, so the very
        // next callback must again report elapsedTime == 0.
        let collector = ElapsedCollector()
        let timer = CADisplayLinkTimer { collector.record($0) }

        // First run: gather a couple of ticks so elapsedTime has advanced past 0.
        timer.start()
        try #require(await Self.spinUntil { collector.values.count >= 2 })
        timer.stop()
        try #require(collector.values.first == 0)
        // The second value of the first run must already be > 0, proving the
        // baseline advanced before we reset it.
        #expect((collector.values.dropFirst().first ?? -1) > 0)

        // Second run: the first new tick should be 0 again.
        collector.reset()
        timer.start()
        try #require(await Self.spinUntil { !collector.values.isEmpty })
        timer.stop()

        #expect(collector.values.first == 0)
    }

    // MARK: - Callback runs on the main actor

    @Test
    func callbackRunsOnMainThread() async throws {
        let observer = MainThreadObserver()
        let timer = CADisplayLinkTimer { _ in observer.recordIsMainThread(Thread.isMainThread) }
        timer.start()
        let fired = await Self.spinUntil { observer.recorded }
        timer.stop()
        try #require(fired)
        #expect(observer.wasMainThread)
    }

    // MARK: - confirmation-based delivery

    @Test
    func confirmationFiresAtLeastOnce() async {
        await confirmation("display link block invoked", expectedCount: 1...) { confirm in
            let didConfirm = ConfirmGate()
            let timer = CADisplayLinkTimer { _ in
                if didConfirm.markIfFirst() { confirm() }
            }
            timer.start()
            await Self.spinUntil { didConfirm.fired }
            timer.stop()
        }
    }

    // MARK: - Independent timers

    @Test
    func multipleIndependentTimersEachFire() async throws {
        // Two timers running simultaneously must each receive their own 0-seeded
        // first callback; their state is independent.
        let a = ElapsedCollector()
        let b = ElapsedCollector()
        let timerA = CADisplayLinkTimer { a.record($0) }
        let timerB = CADisplayLinkTimer { b.record($0) }

        timerA.start()
        timerB.start()
        let bothFired = await Self.spinUntil { !a.values.isEmpty && !b.values.isEmpty }
        timerA.stop()
        timerB.stop()

        try #require(bothFired)
        #expect(a.values.first == 0)
        #expect(b.values.first == 0)
    }

    @Test
    func manyTimersStressNoCrash() async throws {
        // Stress the run loop with many simultaneous links; each must seed its own
        // 0 baseline. Bounded count keeps the test fast and deterministic.
        let count = 20
        let collectors = (0 ..< count).map { _ in ElapsedCollector() }
        let timers = collectors.map { collector in
            CADisplayLinkTimer { collector.record($0) }
        }
        for timer in timers { timer.start() }

        let allFired = await Self.spinUntil { collectors.allSatisfy { !$0.values.isEmpty } }
        for timer in timers { timer.stop() }

        try #require(allFired)
        for collector in collectors {
            #expect(collector.values.first == 0)
        }
    }

    // MARK: - Test-only support types (main-actor isolated, like the timer)

    /// Counts callback invocations; all access is on the main actor since the
    /// timer's block is @MainActor and the suite is @MainActor.
    private final class TickCounter {
        private(set) var value = 0

        func increment() {
            value += 1
        }
    }

    /// Records elapsed-time values delivered to the block.
    private final class ElapsedCollector {
        private(set) var values: [TimeInterval] = []

        func record(_ value: TimeInterval) {
            values.append(value)
        }

        func reset() {
            values.removeAll()
        }
    }

    /// Captures whether the block was observed running on the main thread.
    private final class MainThreadObserver {
        private(set) var recorded = false
        private(set) var wasMainThread = false

        func recordIsMainThread(_ isMain: Bool) {
            guard !recorded else { return }
            recorded = true
            wasMainThread = isMain
        }
    }

    /// One-shot latch so a `confirmation` is signalled exactly once.
    private final class ConfirmGate {
        private(set) var fired = false

        /// Returns true exactly once, on the first call.
        func markIfFirst() -> Bool {
            guard !fired else { return false }
            fired = true
            return true
        }
    }
}
