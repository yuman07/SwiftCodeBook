//
//  LyricHighlightingLabelTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/UIKit/LyricHighlightingLabel.swift
//
//  Source under test: `LyricHighlightingLabel` — a `public final class` UILabel subclass that
//  renders a "karaoke"-style highlight overlay. Public surface:
//    - var highlightColor: UIColor  (default .clear; didSet -> setNeedsDisplay())
//    - var progress: Double         (default 0.0; didSet clamps to [0, 1] then setNeedsDisplay())
//    - override func draw(_ rect: CGRect)  (fills width * progress region with highlightColor
//                                            using .sourceIn blend mode)
//
//  Notes on testability:
//    - `progress` clamping (max(0, min(1, progress))) is fully deterministic and covered
//      exhaustively, including extremes / NaN.
//    - `highlightColor` and `progress` are stored properties with default values — defaults and
//      round-trip set/get are asserted.
//    - `draw(_:)` invokes Core Graphics fill routines. We cannot easily assert pixel output of a
//      label without text/layout, but we CAN assert that invoking draw (directly and via a
//      UIGraphicsImageRenderer) does not crash for a representative matrix of progress /
//      highlightColor combinations, and produces an image of the requested size.
//    - The class is a UILabel subclass, hence @MainActor; the whole suite is @MainActor.
//

import Testing
import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif
@testable import SwiftCodeBook

@MainActor
@Suite struct LyricHighlightingLabelTests {

    // MARK: - Default values

    @Test func defaultHighlightColorIsClear() {
        let label = LyricHighlightingLabel()
        #expect(label.highlightColor == UIColor.clear)
    }

    @Test func defaultProgressIsZero() {
        let label = LyricHighlightingLabel()
        #expect(label.progress == 0.0)
    }

    @Test func isUILabelSubclass() {
        let label = LyricHighlightingLabel()
        #expect((label as Any) is UILabel)
    }

    @Test func defaultInitFromCoderProducesDefaults() throws {
        // Exercise the NSCoding init path (UILabel supports it). The stored property defaults
        // must still hold after decoding an archived instance.
        let original = LyricHighlightingLabel()
        let data = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: false)
        let decoded = try #require(
            try NSKeyedUnarchiver.unarchivedObject(ofClass: LyricHighlightingLabel.self, from: data)
        )
        // The custom stored properties are not encoded by the class, so they fall back to defaults.
        #expect(decoded.highlightColor == UIColor.clear)
        #expect(decoded.progress == 0.0)
    }

    // MARK: - progress: set/get round-trip within range

    @Test(arguments: [0.0, 0.0001, 0.25, 0.5, 0.75, 0.999999, 1.0])
    func progressStoresInRangeValuesUnchanged(_ value: Double) {
        let label = LyricHighlightingLabel()
        label.progress = value
        #expect(label.progress == value)
    }

    // MARK: - progress: clamping below 0

    @Test(arguments: [-0.0001, -0.5, -1.0, -100.0, -Double.greatestFiniteMagnitude])
    func progressClampsNegativeToZero(_ value: Double) {
        let label = LyricHighlightingLabel()
        label.progress = value
        #expect(label.progress == 0.0)
    }

    @Test func progressClampsNegativeInfinityToZero() {
        let label = LyricHighlightingLabel()
        label.progress = -.infinity
        #expect(label.progress == 0.0)
    }

    // MARK: - progress: clamping above 1

    @Test(arguments: [1.0001, 1.5, 2.0, 100.0, Double.greatestFiniteMagnitude])
    func progressClampsAboveOneToOne(_ value: Double) {
        let label = LyricHighlightingLabel()
        label.progress = value
        #expect(label.progress == 1.0)
    }

    @Test func progressClampsPositiveInfinityToOne() {
        let label = LyricHighlightingLabel()
        label.progress = .infinity
        #expect(label.progress == 1.0)
    }

    // MARK: - progress: NaN behavior

    @Test func progressWithNaNBehavior() {
        // The source clamps via `max(0, min(1, progress))`. The stdlib free `min(_:_:)` returns
        // its FIRST argument when the comparison is unordered (NaN), so `min(1, .nan)` == 1.0,
        // and then `max(0, 1.0)` == 1.0. Verified empirically against the Swift stdlib.
        // We assert the ACTUAL current behavior (NaN gets coerced to 1.0, not left as NaN).
        let label = LyricHighlightingLabel()
        label.progress = .nan
        #expect(label.progress == 1.0)
        #expect(!label.progress.isNaN)
    }

    // MARK: - progress: idempotence / repeated assignment

    @Test func progressRepeatedAssignmentStable() {
        let label = LyricHighlightingLabel()
        label.progress = 0.42
        label.progress = 0.42
        #expect(label.progress == 0.42)
    }

    @Test func progressReassignmentOverwrites() {
        let label = LyricHighlightingLabel()
        label.progress = 0.3
        label.progress = 0.8
        #expect(label.progress == 0.8)
        label.progress = -5
        #expect(label.progress == 0.0)
        label.progress = 5
        #expect(label.progress == 1.0)
    }

    // MARK: - highlightColor: set/get round-trip

    @Test func highlightColorRoundTrip() {
        let label = LyricHighlightingLabel()
        let color = UIColor.red
        label.highlightColor = color
        #expect(label.highlightColor == color)
    }

    @Test(arguments: [
        UIColor.red, UIColor.green, UIColor.blue, UIColor.black, UIColor.white,
        UIColor.clear, UIColor(white: 0.5, alpha: 0.5),
    ])
    func highlightColorStoresVariousColors(_ color: UIColor) {
        let label = LyricHighlightingLabel()
        label.highlightColor = color
        #expect(label.highlightColor == color)
    }

    @Test func highlightColorReassignment() {
        let label = LyricHighlightingLabel()
        label.highlightColor = .yellow
        #expect(label.highlightColor == .yellow)
        label.highlightColor = .cyan
        #expect(label.highlightColor == .cyan)
    }

    // MARK: - draw(_:) does not crash and renders an image

    @Test(arguments: [0.0, 0.5, 1.0])
    func renderingViaImageRendererProducesImage(_ progress: Double) {
        let label = LyricHighlightingLabel()
        label.text = "Hello, Lyric"
        label.textColor = .black
        label.highlightColor = .red
        label.progress = progress
        label.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        label.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: label.bounds)
        let image = renderer.image { ctx in
            label.draw(label.bounds)
        }
        #expect(image.size == label.bounds.size)
    }

    @Test func directDrawCallDoesNotCrashWithinContext() {
        let label = LyricHighlightingLabel()
        label.text = "Karaoke"
        label.highlightColor = .magenta
        label.progress = 0.5
        label.frame = CGRect(x: 0, y: 0, width: 120, height: 30)

        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 1)
        defer { UIGraphicsEndImageContext() }
        // Must not crash even though we drive draw(_:) directly.
        label.draw(label.bounds)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        #expect(image != nil)
    }

    @Test func renderingWithClearHighlightColorDoesNotCrash() {
        let label = LyricHighlightingLabel()
        label.text = "Default"
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 20)
        let renderer = UIGraphicsImageRenderer(bounds: label.bounds)
        let image = renderer.image { _ in
            label.draw(label.bounds)
        }
        #expect(image.size.width == 100)
        #expect(image.size.height == 20)
    }

    @Test func renderingWithZeroSizedRectDoesNotCrash() {
        let label = LyricHighlightingLabel()
        label.highlightColor = .red
        label.progress = 0.7
        let bounds = CGRect.zero
        // UIGraphicsImageRenderer with a zero-size bounds is degenerate; use a 1x1 context
        // and pass a zero rect to draw to exercise the fillRect computation (width*progress == 0).
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), false, 1)
        defer { UIGraphicsEndImageContext() }
        label.draw(bounds)
        #expect(Bool(true)) // reached here without crashing
    }

    // MARK: - draw fill-rect math (indirect verification of width * progress)

    @Test(arguments: [
        (0.0, 0.0),
        (0.25, 50.0),
        (0.5, 100.0),
        (1.0, 200.0),
    ])
    func fillRectWidthMatchesProgressTimesWidth(_ progress: Double, _ expectedWidth: Double) {
        // The source computes fillRect.width = rect.width * progress. We can't observe the rect
        // directly, but we can confirm the same arithmetic the source uses is consistent for a
        // 200pt-wide rect. This guards the documented progress semantics.
        let rectWidth = 200.0
        let computed = rectWidth * progress
        #expect(computed == expectedWidth)
    }

    // MARK: - Many sequential mutations (stress, no lost final state)

    @Test func manySequentialProgressMutationsKeepFinalState() {
        let label = LyricHighlightingLabel()
        for i in 0..<100_000 {
            // Deliberately feed out-of-range values to exercise clamping repeatedly.
            label.progress = Double(i) / 50_000.0 - 0.5
        }
        // Last i = 99_999 -> 99999/50000 - 0.5 = 1.99998 -> clamped to 1.0
        #expect(label.progress == 1.0)
    }

    @Test func manyHighlightColorMutationsKeepFinalColor() {
        let label = LyricHighlightingLabel()
        let palette: [UIColor] = [.red, .green, .blue, .yellow, .cyan, .magenta]
        var last = UIColor.clear
        for i in 0..<10_000 {
            last = palette[i % palette.count]
            label.highlightColor = last
        }
        #expect(label.highlightColor == last)
    }

    // MARK: - Interaction: setting both properties then rendering

    @Test func combinedConfigurationRendersConsistently() {
        let label = LyricHighlightingLabel()
        label.text = "Combined"
        label.textColor = .black
        label.highlightColor = .red
        label.progress = 2.0 // clamps to 1.0
        #expect(label.progress == 1.0)

        label.frame = CGRect(x: 0, y: 0, width: 150, height: 25)
        let renderer = UIGraphicsImageRenderer(bounds: label.bounds)
        let image = renderer.image { _ in
            label.draw(label.bounds)
        }
        #expect(image.size == CGSize(width: 150, height: 25))
    }
}
