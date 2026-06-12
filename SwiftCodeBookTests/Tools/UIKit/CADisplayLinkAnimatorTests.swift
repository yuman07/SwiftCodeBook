//
//  CADisplayLinkAnimatorTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/UIKit/CADisplayLinkAnimator.swift
//
//  Source under test: `CADisplayLinkAnimator` — a @MainActor animator driven by a
//  CADisplayLink that interpolates a CGFloat progress value through a CAMediaTimingFunction
//  cubic-bezier curve. Public surface:
//    init(duration:timingFunctionName:preferredFrameRateRange:)
//    startAnimation(), finishAnimation(at:), addAnimation(_:), addCompletion(_:), reset()
//
//  Notes on testability:
//    - `finishAnimation(at:)`, `addAnimation`, `addCompletion`, `reset` are fully deterministic
//      and are covered exhaustively below.
//    - `startAnimation()` spins a real CADisplayLink on the main run loop; its precise per-frame
//      timing is non-deterministic, so those tests assert only structural invariants
//      (no crash, eventual progress, eventual completion) using `confirmation` + run-loop yielding.
//      The yielding helper exits early once a caller-supplied predicate is satisfied, so a
//      successful test finishes promptly while a stuck run loop is still bounded by the budget.
//    - The internal `CubicBezier` math and `CADisplayLinkTimer` are exercised indirectly through
//      the progress values delivered to animation closures (.end -> 1, .start -> 0) and through
//      the run-loop-driven `startAnimation()` path. `Duration.seconds` is a project extension.
//

import Testing
import Foundation
import QuartzCore
#if canImport(UIKit)
import UIKit
#endif
@testable import SwiftCodeBook

@Suite struct CADisplayLinkAnimatorTests {

    // MARK: - finishAnimation(at: .end)

    @Test @MainActor func finishAtEndCallsAnimationsWithOne() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var received = [CGFloat]()
        animator.addAnimation { received.append($0) }
        animator.finishAnimation(at: .end)
        #expect(received == [1])
    }

    @Test @MainActor func finishAtEndCallsCompletionsWithEnd() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var positions = [UIViewAnimatingPosition]()
        animator.addCompletion { positions.append($0) }
        animator.finishAnimation(at: .end)
        #expect(positions == [.end])
    }

    @Test @MainActor func finishAtEndRunsAnimationsBeforeCompletions() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var order = [String]()
        // Interleave registration to prove ordering is governed by closure *kind*
        // (all animations, then all completions) and not registration interleaving.
        animator.addCompletion { _ in order.append("comp") }
        animator.addAnimation { _ in order.append("anim") }
        animator.addCompletion { _ in order.append("comp") }
        animator.addAnimation { _ in order.append("anim") }
        animator.finishAnimation(at: .end)
        #expect(order == ["anim", "anim", "comp", "comp"])
    }

    // MARK: - finishAnimation(at: .start)

    @Test @MainActor func finishAtStartCallsAnimationsWithZero() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var received = [CGFloat]()
        animator.addAnimation { received.append($0) }
        animator.finishAnimation(at: .start)
        #expect(received == [0])
    }

    @Test @MainActor func finishAtStartCallsCompletionsWithStart() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var positions = [UIViewAnimatingPosition]()
        animator.addCompletion { positions.append($0) }
        animator.finishAnimation(at: .start)
        #expect(positions == [.start])
    }

    @Test @MainActor func finishAtStartRunsAnimationsBeforeCompletions() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var order = [String]()
        animator.addCompletion { _ in order.append("comp") }
        animator.addAnimation { _ in order.append("anim") }
        animator.finishAnimation(at: .start)
        #expect(order == ["anim", "comp"])
    }

    // MARK: - finishAnimation(at: .current)

    @Test @MainActor func finishAtCurrentSkipsAnimations() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var animCount = 0
        var positions = [UIViewAnimatingPosition]()
        animator.addAnimation { _ in animCount += 1 }
        animator.addCompletion { positions.append($0) }
        animator.finishAnimation(at: .current)
        // .current does NOT invoke animation closures, only completions.
        #expect(animCount == 0)
        #expect(positions == [.current])
    }

    @Test @MainActor func finishAtCurrentSkipsAllAnimationsButFiresAllCompletions() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var animCount = 0
        var compCount = 0
        for _ in 0 ..< 4 { animator.addAnimation { _ in animCount += 1 } }
        for _ in 0 ..< 7 { animator.addCompletion { _ in compCount += 1 } }
        animator.finishAnimation(at: .current)
        #expect(animCount == 0)
        #expect(compCount == 7)
    }

    // MARK: - Multiple registered closures

    @Test @MainActor func multipleAnimationsAndCompletionsAllFire() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var animValues = [CGFloat]()
        var compPositions = [UIViewAnimatingPosition]()
        for _ in 0 ..< 5 { animator.addAnimation { animValues.append($0) } }
        for _ in 0 ..< 3 { animator.addCompletion { compPositions.append($0) } }
        animator.finishAnimation(at: .end)
        #expect(animValues == [1, 1, 1, 1, 1])
        #expect(compPositions == [.end, .end, .end])
    }

    @Test @MainActor func animationsPreserveRegistrationOrder() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var order = [Int]()
        for i in 0 ..< 10 { animator.addAnimation { _ in order.append(i) } }
        animator.finishAnimation(at: .start)
        #expect(order == Array(0 ..< 10))
    }

    @Test @MainActor func completionsPreserveRegistrationOrder() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var order = [Int]()
        for i in 0 ..< 10 { animator.addCompletion { _ in order.append(i) } }
        animator.finishAnimation(at: .current)
        #expect(order == Array(0 ..< 10))
    }

    // MARK: - finishAnimation resets internal state (single-shot semantics)

    @Test @MainActor func finishConsumesClosuresSoSecondFinishIsNoOp() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var animCount = 0
        var compCount = 0
        animator.addAnimation { _ in animCount += 1 }
        animator.addCompletion { _ in compCount += 1 }
        animator.finishAnimation(at: .end)
        #expect(animCount == 1)
        #expect(compCount == 1)
        // Closures were cleared by the internal reset(); a second finish must not re-fire them.
        animator.finishAnimation(at: .end)
        animator.finishAnimation(at: .start)
        animator.finishAnimation(at: .current)
        #expect(animCount == 1)
        #expect(compCount == 1)
    }

    @Test @MainActor func resetClearsAnimationsAndCompletions() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var animCount = 0
        var compCount = 0
        animator.addAnimation { _ in animCount += 1 }
        animator.addCompletion { _ in compCount += 1 }
        animator.reset()
        animator.finishAnimation(at: .end)
        // Nothing should fire after reset.
        #expect(animCount == 0)
        #expect(compCount == 0)
    }

    @Test @MainActor func resetIsIdempotent() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        animator.addAnimation { _ in }
        animator.reset()
        animator.reset()
        animator.reset()
        var fired = false
        animator.addAnimation { _ in fired = true }
        animator.finishAnimation(at: .end)
        // The animation added AFTER reset should still work.
        #expect(fired)
    }

    // MARK: - No registered closures

    @Test @MainActor func finishWithNoClosuresDoesNotCrash() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        animator.finishAnimation(at: .end)
        animator.finishAnimation(at: .start)
        animator.finishAnimation(at: .current)
        // Reaching here without a crash is the assertion.
        #expect(Bool(true))
    }

    @Test @MainActor func resetWithNoClosuresDoesNotCrash() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        animator.reset()
        animator.reset()
        #expect(Bool(true))
    }

    @Test @MainActor func addClosuresAfterFinishStillWork() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        animator.finishAnimation(at: .end)
        var value: CGFloat = -1
        animator.addAnimation { value = $0 }
        animator.finishAnimation(at: .end)
        #expect(value == 1)
    }

    @Test @MainActor func reAddAfterFinishThenFinishAtStartDeliversZero() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        animator.addAnimation { _ in }
        animator.finishAnimation(at: .end)
        var value: CGFloat = -1
        var position: UIViewAnimatingPosition?
        animator.addAnimation { value = $0 }
        animator.addCompletion { position = $0 }
        animator.finishAnimation(at: .start)
        #expect(value == 0)
        #expect(position == .start)
    }

    // MARK: - Parameterized over all final positions

    @Test(arguments: [
        UIViewAnimatingPosition.end,
        UIViewAnimatingPosition.start,
        UIViewAnimatingPosition.current,
    ])
    @MainActor
    func completionReceivesMatchingPosition(_ pos: UIViewAnimatingPosition) {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var received: UIViewAnimatingPosition?
        animator.addCompletion { received = $0 }
        animator.finishAnimation(at: pos)
        #expect(received == pos)
    }

    @Test(arguments: [
        (UIViewAnimatingPosition.end, CGFloat(1)),
        (UIViewAnimatingPosition.start, CGFloat(0)),
    ])
    @MainActor
    func animationReceivesExpectedTerminalProgress(_ pos: UIViewAnimatingPosition, _ expected: CGFloat) {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        var received: CGFloat?
        animator.addAnimation { received = $0 }
        animator.finishAnimation(at: pos)
        #expect(received == expected)
    }

    // MARK: - Various timing function names construct & finish correctly

    @Test(arguments: [
        CAMediaTimingFunctionName.default,
        .linear,
        .easeIn,
        .easeOut,
        .easeInEaseOut,
    ])
    @MainActor
    func variousTimingFunctionsFinishAtTerminalValues(_ name: CAMediaTimingFunctionName) {
        let animator = CADisplayLinkAnimator(duration: .seconds(1), timingFunctionName: name)
        var endValue: CGFloat?
        var startValue: CGFloat?
        animator.addAnimation { endValue = $0 }
        animator.finishAnimation(at: .end)
        #expect(endValue == 1)

        animator.addAnimation { startValue = $0 }
        animator.finishAnimation(at: .start)
        #expect(startValue == 0)
    }

    // MARK: - Various durations construct correctly

    @Test(arguments: [
        Duration.seconds(0),
        .seconds(1),
        .milliseconds(250),
        .seconds(10),
        .nanoseconds(1),
        // Negative duration is a degenerate input; `finishAnimation` does not consult duration,
        // so the deterministic terminal path must still fire normally.
        .seconds(-1),
    ])
    @MainActor
    func variousDurationsConstructAndFinish(_ duration: Duration) {
        let animator = CADisplayLinkAnimator(duration: duration)
        var fired = false
        animator.addCompletion { _ in fired = true }
        animator.finishAnimation(at: .end)
        #expect(fired)
    }

    // MARK: - preferredFrameRateRange variants

    @Test @MainActor func customFrameRateRangeConstructs() {
        let range = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        let animator = CADisplayLinkAnimator(
            duration: .seconds(1),
            timingFunctionName: .easeInEaseOut,
            preferredFrameRateRange: range
        )
        var fired = false
        animator.addCompletion { _ in fired = true }
        animator.finishAnimation(at: .end)
        #expect(fired)
    }

    @Test @MainActor func nilFrameRateRangeConstructs() {
        let animator = CADisplayLinkAnimator(
            duration: .seconds(1),
            preferredFrameRateRange: nil
        )
        var fired = false
        animator.addCompletion { _ in fired = true }
        animator.finishAnimation(at: .end)
        #expect(fired)
    }

    // MARK: - startAnimation()  (run-loop driven, structural assertions only)

    @Test @MainActor func startAnimationDeliversInitialProgress() async {
        // The first display-link callback fires block(0); for a finite, positive duration
        // the animator delivers progress 0 (which is < 1) to the animation closure rather
        // than immediately finishing. We confirm at least one animation tick occurs and that
        // every delivered progress value stays within the clamped [0, 1] range.
        let animator = CADisplayLinkAnimator(duration: .seconds(2))
        await confirmation("animation closure is invoked at least once", expectedCount: 1) { confirm in
            var seenFirst = false
            var allInRange = true
            animator.addAnimation { progress in
                if progress < 0 || progress > 1 { allInRange = false }
                if !seenFirst {
                    seenFirst = true
                    confirm()
                }
            }
            animator.startAnimation()
            // Yield to the main run loop so CADisplayLink can fire frames; stop as soon as
            // the first tick lands.
            await Self.spinMainRunLoop(maxIterations: 600) { seenFirst }
            #expect(allInRange)
        }
        animator.reset()
    }

    @Test @MainActor func startAnimationEventuallyCompletesForShortDuration() async {
        // With a very short duration, progress reaches >= 1 quickly and the animator
        // finishes at .end, firing the completion exactly with .end.
        let animator = CADisplayLinkAnimator(duration: .milliseconds(1))
        await confirmation("completion fires with .end", expectedCount: 1) { confirm in
            var done = false
            animator.addCompletion { position in
                if !done {
                    done = true
                    #expect(position == .end)
                    confirm()
                }
            }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { done }
        }
        animator.reset()
    }

    @Test @MainActor func startAnimationWithZeroDurationFinishesImmediatelyAtEnd() async {
        // A zero (non-positive) duration trips the `seconds > 0` guard inside updateAnimation,
        // so the very first display-link tick routes straight to finishAnimation(at: .end):
        // the animation closure receives 1 and the completion receives .end.
        let animator = CADisplayLinkAnimator(duration: .seconds(0))
        await confirmation("zero-duration run completes at .end", expectedCount: 1) { confirm in
            var done = false
            var lastProgress: CGFloat?
            animator.addAnimation { lastProgress = $0 }
            animator.addCompletion { position in
                if !done {
                    done = true
                    #expect(position == .end)
                    #expect(lastProgress == 1)
                    confirm()
                }
            }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { done }
        }
        animator.reset()
    }

    @Test @MainActor func startAnimationProgressIsMonotonicNonDecreasing() async {
        // The cubic-bezier easing for .easeInEaseOut yields monotonic non-decreasing
        // progress over time. Verify the delivered values never go backwards.
        let animator = CADisplayLinkAnimator(duration: .milliseconds(80), timingFunctionName: .easeInEaseOut)
        var last: CGFloat = -1
        var monotonic = true
        await confirmation("animation runs to completion", expectedCount: 1) { confirm in
            var finished = false
            animator.addAnimation { progress in
                if progress + 1e-9 < last { monotonic = false }
                last = progress
            }
            animator.addCompletion { _ in
                if !finished { finished = true; confirm() }
            }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { finished }
        }
        #expect(monotonic)
        animator.reset()
    }

    @Test @MainActor func resetDuringAnimationStopsFurtherTicks() async {
        // After reset(), the display link is invalidated and the cleared closures must not fire.
        let animator = CADisplayLinkAnimator(duration: .seconds(5))
        var tickCount = 0
        animator.addAnimation { _ in tickCount += 1 }
        animator.startAnimation()
        // Let a couple of frames pass (stop early once at least one tick lands).
        await Self.spinMainRunLoop(maxIterations: 60) { tickCount > 0 }
        animator.reset()
        let countAfterReset = tickCount
        // Spin further; no new ticks should arrive because the closure was removed and timer stopped.
        await Self.spinMainRunLoop(maxIterations: 30) { false }
        #expect(tickCount == countAfterReset)
    }

    @Test @MainActor func startAnimationIsRestartable() async {
        // Calling startAnimation() again replaces the timer cleanly (CADisplayLinkTimer.start
        // stops any prior link first). Both runs should be able to complete.
        let animator = CADisplayLinkAnimator(duration: .milliseconds(1))

        await confirmation("first run completes", expectedCount: 1) { confirm in
            var done = false
            animator.addCompletion { _ in if !done { done = true; confirm() } }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { done }
        }

        // After finishing, internal state was reset; set up a fresh run.
        await confirmation("second run completes", expectedCount: 1) { confirm in
            var done = false
            animator.addCompletion { _ in if !done { done = true; confirm() } }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { done }
        }
        animator.reset()
    }

    @Test @MainActor func restartReplacesAnimationsRatherThanAccumulating() async {
        // The first run finishes and resets internal state, so the second run's completion
        // must fire exactly once (the first run's completion was consumed, not retained).
        let animator = CADisplayLinkAnimator(duration: .milliseconds(1))
        var firstRunCompletions = 0
        await confirmation("first run completes", expectedCount: 1) { confirm in
            var done = false
            animator.addCompletion { _ in
                firstRunCompletions += 1
                if !done { done = true; confirm() }
            }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 600) { done }
        }
        let secondRunCompletions = await {
            var count = 0
            await confirmation("second run completes", expectedCount: 1) { confirm in
                var done = false
                animator.addCompletion { _ in
                    count += 1
                    if !done { done = true; confirm() }
                }
                animator.startAnimation()
                await Self.spinMainRunLoop(maxIterations: 600) { done }
            }
            return count
        }()
        #expect(firstRunCompletions == 1)
        #expect(secondRunCompletions == 1)
        animator.reset()
    }

    // MARK: - Large data / many closures

    @Test @MainActor func manyClosuresAllFireWithTerminalValues() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        let count = 100_000
        var animSum = 0
        var compEndCount = 0
        for _ in 0 ..< count {
            animator.addAnimation { p in animSum += Int(p) } // p == 1 on .end
            animator.addCompletion { pos in if pos == .end { compEndCount += 1 } }
        }
        animator.finishAnimation(at: .end)
        #expect(animSum == count)        // each animation receives progress 1
        #expect(compEndCount == count)   // each completion receives .end
        // Single-shot: the large registration was consumed; a second finish fires nothing.
        animator.finishAnimation(at: .end)
        #expect(animSum == count)
        #expect(compEndCount == count)
    }

    @Test @MainActor func manyClosuresAtStartDeliverZero() {
        let animator = CADisplayLinkAnimator(duration: .seconds(1))
        let count = 50_000
        var nonZero = 0
        var compStartCount = 0
        for _ in 0 ..< count {
            animator.addAnimation { p in if p != 0 { nonZero += 1 } }
            animator.addCompletion { pos in if pos == .start { compStartCount += 1 } }
        }
        animator.finishAnimation(at: .start)
        #expect(nonZero == 0)
        #expect(compStartCount == count)
    }

    // MARK: - deinit cleanup

    @Test @MainActor func deinitWhileAnimatingDoesNotCrash() async {
        // Create, start, drop. deinit calls reset() which invalidates the display link.
        do {
            let animator = CADisplayLinkAnimator(duration: .seconds(10))
            animator.addAnimation { _ in }
            animator.startAnimation()
            await Self.spinMainRunLoop(maxIterations: 5) { false }
            // animator goes out of scope here -> deinit -> reset()
        }
        // Spin a little more to let any lingering run-loop sources drain.
        await Self.spinMainRunLoop(maxIterations: 5) { false }
        #expect(Bool(true))
    }

    @Test @MainActor func deinitWithoutStartingDoesNotCrash() {
        do {
            let animator = CADisplayLinkAnimator(duration: .seconds(1))
            animator.addAnimation { _ in }
            animator.addCompletion { _ in }
            // No startAnimation(); just drop it. deinit -> reset() with an inactive timer.
        }
        #expect(Bool(true))
    }

    // MARK: - Helpers

    /// Yields control back to the main run loop repeatedly so an attached CADisplayLink can
    /// deliver frames. We do NOT use Task.sleep for synchronization; instead each iteration
    /// suspends on a continuation resumed by a tiny `DispatchQueue.main.asyncAfter`, which lets
    /// the run loop spin and fire display-link callbacks before we resume.
    ///
    /// The loop exits as soon as `stop()` becomes true (so a successful test returns promptly)
    /// and is otherwise bounded by `maxIterations` (so the test always terminates even if the
    /// run loop never delivers a frame). Callers gate their real assertions on a `confirmation`,
    /// which fails loudly if the expected event never occurs — there is no time-value assertion,
    /// so frame-timing variability cannot make this flaky.
    @MainActor
    private static func spinMainRunLoop(maxIterations: Int, until stop: @MainActor () -> Bool) async {
        for _ in 0 ..< maxIterations {
            if stop() { return }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                // A short, bounded hop on the main queue: gives the run loop a slice of time
                // to service the CADisplayLink source, then resumes us.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                    cont.resume()
                }
            }
        }
    }
}
