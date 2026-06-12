//
//  GradientViewTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/UIKit/GradientView.swift
//
//  GradientView is a `public final class GradientView: UIView` whose backing
//  layer is a `CAGradientLayer` (overridden `layerClass`). It exposes typed
//  Swift wrappers over the underlying layer:
//    - override class var layerClass: AnyClass  -> CAGradientLayer.self
//    - var colors: [UIColor]        (round-trips through [CGColor])
//    - var locations: [CGFloat]     (round-trips through [NSNumber])
//    - var startPoint: CGPoint      (direct passthrough to layer.startPoint)
//    - var endPoint: CGPoint        (direct passthrough to layer.endPoint)
//    - var type: CAGradientLayerType(direct passthrough to layer.type)
//
//  GradientView is a UIKit @MainActor type, so the whole suite is pinned to
//  @MainActor. The `gradientLayer` accessor and the `NSNumber.cgFloatValue`
//  helper (from NSNumber+Tools.swift, `CGFloat(doubleValue)`) used by
//  `locations` are private/extension symbols, so they are exercised
//  indirectly through the public surface.
//
//  Note on color comparison: `colors` is stored as CGColor on the layer and
//  reconstructed as `UIColor(cgColor:)` on read. Equality is therefore checked
//  via the resolved RGBA components (a fresh UIColor wrapper is not guaranteed
//  `==` to the original UIColor instance), so we compare components instead.
//

import Foundation
import UIKit
import Testing
@testable import SwiftCodeBook

@Suite @MainActor struct GradientViewTests {

    // MARK: - Helpers

    /// Resolves a UIColor to its RGBA components (in its native color space).
    /// Returns nil if the color cannot be converted to RGBA.
    private func rgba(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }

    /// Asserts two UIColors resolve to the same RGBA components within tolerance.
    private func expectSameColor(_ lhs: UIColor, _ rhs: UIColor,
                                 tolerance: CGFloat = 1e-6,
                                 sourceLocation: SourceLocation = #_sourceLocation) {
        guard let a = rgba(lhs), let b = rgba(rhs) else {
            #expect(Bool(false), "color not convertible to RGBA", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(a.r - b.r) <= tolerance, "red mismatch", sourceLocation: sourceLocation)
        #expect(abs(a.g - b.g) <= tolerance, "green mismatch", sourceLocation: sourceLocation)
        #expect(abs(a.b - b.b) <= tolerance, "blue mismatch", sourceLocation: sourceLocation)
        #expect(abs(a.a - b.a) <= tolerance, "alpha mismatch", sourceLocation: sourceLocation)
    }

    /// The view's backing layer, downcast to CAGradientLayer (the documented type).
    private func gradientLayer(of view: GradientView) -> CAGradientLayer {
        view.layer as! CAGradientLayer
    }

    // MARK: - layerClass / backing layer

    @Test func layerClassIsCAGradientLayer() {
        // Compare the metatypes outside the macro: the `==` overload on
        // metatypes is ambiguous inside `#expect` (it can resolve to the
        // `_OptionalNilComparisonType` overload), so resolve to Bool first.
        let isGradientLayerClass: Bool = GradientView.layerClass == CAGradientLayer.self
        #expect(isGradientLayerClass)
    }

    @Test func backingLayerIsCAGradientLayerInstance() {
        let view = GradientView()
        #expect(view.layer is CAGradientLayer)
    }

    @Test func defaultInitSucceeds() {
        let view = GradientView()
        // A freshly created view has no colors/locations set yet.
        #expect(view.colors.isEmpty)
        #expect(view.locations.isEmpty)
        // And starts as an axial gradient (the CAGradientLayer default).
        #expect(view.type == .axial)
    }

    @Test func initWithFrameSucceeds() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 200)
        let view = GradientView(frame: frame)
        #expect(view.frame == frame)
        #expect(view.layer is CAGradientLayer)
        #expect(view.colors.isEmpty)
        #expect(view.locations.isEmpty)
    }

    @Test func initWithZeroFrameSucceeds() {
        let view = GradientView(frame: .zero)
        #expect(view.frame == .zero)
        #expect(view.layer is CAGradientLayer)
    }

    @Test func backingLayerIdentityIsStable() {
        // The downcast accessor must return the same layer instance every call.
        let view = GradientView()
        #expect(gradientLayer(of: view) === gradientLayer(of: view))
        #expect(view.layer === gradientLayer(of: view))
    }

    // MARK: - colors get/set round-trip

    @Test func colorsDefaultIsEmpty() {
        let view = GradientView()
        #expect(view.colors.isEmpty)
    }

    @Test func setAndGetSingleColor() throws {
        let view = GradientView()
        view.colors = [.red]
        let got = view.colors
        #expect(got.count == 1)
        expectSameColor(try #require(got.first), .red)
    }

    @Test func setAndGetMultipleColors() {
        let view = GradientView()
        let input: [UIColor] = [.red, .green, .blue]
        view.colors = input
        let got = view.colors
        #expect(got.count == input.count)
        for (a, b) in zip(got, input) {
            expectSameColor(a, b)
        }
    }

    @Test func setColorsWritesThroughToLayer() throws {
        let view = GradientView()
        view.colors = [.red, .blue]
        let layer = gradientLayer(of: view)
        let layerColors = try #require(layer.colors as? [CGColor])
        #expect(layerColors.count == 2)
        // Round-trip each layer CGColor back to UIColor and compare.
        expectSameColor(UIColor(cgColor: layerColors[0]), .red)
        expectSameColor(UIColor(cgColor: layerColors[1]), .blue)
    }

    @Test func setEmptyColorsRoundTrips() {
        let view = GradientView()
        view.colors = [.red, .green]
        #expect(view.colors.count == 2)
        view.colors = []
        #expect(view.colors.isEmpty)
        // Setting an empty array writes an empty (non-nil) array to the layer.
        #expect(gradientLayer(of: view).colors?.isEmpty ?? false)
    }

    @Test func overwriteColorsReplacesPrevious() throws {
        let view = GradientView()
        view.colors = [.red, .green, .blue]
        #expect(view.colors.count == 3)
        view.colors = [.black]
        let got = view.colors
        #expect(got.count == 1)
        expectSameColor(try #require(got.first), .black)
    }

    @Test func colorsPreservesOrder() {
        let view = GradientView()
        let input: [UIColor] = [.cyan, .magenta, .yellow, .orange]
        view.colors = input
        let got = view.colors
        #expect(got.count == input.count)
        for (a, b) in zip(got, input) {
            expectSameColor(a, b)
        }
    }

    @Test func colorsRoundTripCustomRGBA() throws {
        let view = GradientView()
        let custom = UIColor(red: 0.12, green: 0.34, blue: 0.56, alpha: 0.78)
        view.colors = [custom]
        let got = try #require(view.colors.first)
        expectSameColor(got, custom)
    }

    @Test func colorsRoundTripFullyTransparent() throws {
        let view = GradientView()
        let clear = UIColor(white: 0, alpha: 0)
        view.colors = [clear]
        let got = try #require(view.colors.first)
        let comps = try #require(rgba(got))
        #expect(abs(comps.a - 0) <= 1e-6)
    }

    @Test func colorsRoundTripMixedAlpha() throws {
        // A single set call carrying channels with distinct, non-trivial alphas
        // must preserve each color's components and alpha independently.
        let view = GradientView()
        let input: [UIColor] = [
            UIColor(red: 1, green: 0, blue: 0, alpha: 1.0),
            UIColor(red: 0, green: 1, blue: 0, alpha: 0.5),
            UIColor(red: 0, green: 0, blue: 1, alpha: 0.25),
            UIColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        ]
        view.colors = input
        let got = view.colors
        #expect(got.count == input.count)
        for (a, b) in zip(got, input) {
            expectSameColor(a, b)
        }
    }

    @Test func colorsRoundTripBoundaryComponents() throws {
        // Exact 0 and 1 channel values must survive the CGColor round-trip.
        let view = GradientView()
        let input: [UIColor] = [
            UIColor(red: 0, green: 0, blue: 0, alpha: 1),
            UIColor(red: 1, green: 1, blue: 1, alpha: 1),
        ]
        view.colors = input
        let got = view.colors
        #expect(got.count == 2)
        let black = try #require(rgba(got[0]))
        #expect(abs(black.r) <= 1e-6 && abs(black.g) <= 1e-6 && abs(black.b) <= 1e-6)
        let white = try #require(rgba(got[1]))
        #expect(abs(white.r - 1) <= 1e-6 && abs(white.g - 1) <= 1e-6 && abs(white.b - 1) <= 1e-6)
    }

    @Test func colorsGetterReturnsFreshSnapshot() {
        // The getter rebuilds the array each call; mutating one read must not
        // affect a subsequent read.
        let view = GradientView()
        view.colors = [.red, .green]
        var first = view.colors
        first.removeAll()
        #expect(first.isEmpty)
        #expect(view.colors.count == 2)
    }

    @Test func colorsViaInitWithFrameRoundTrips() {
        // Property surface must behave identically regardless of the init path.
        let view = GradientView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.colors = [.red, .blue]
        let got = view.colors
        #expect(got.count == 2)
        expectSameColor(got[0], .red)
        expectSameColor(got[1], .blue)
    }

    @Test func colorsLargeArray() {
        let view = GradientView()
        let count = 100_000
        let input = (0..<count).map { i -> UIColor in
            let v = CGFloat(i % 256) / 255.0
            return UIColor(red: v, green: v, blue: v, alpha: 1)
        }
        view.colors = input
        let got = view.colors
        #expect(got.count == count)
        // Spot-check first / middle / last to keep the test time-bounded.
        expectSameColor(got[0], input[0])
        expectSameColor(got[count / 2], input[count / 2])
        expectSameColor(got[count - 1], input[count - 1])
    }

    // MARK: - locations get/set round-trip

    @Test func locationsDefaultIsEmpty() {
        let view = GradientView()
        #expect(view.locations.isEmpty)
    }

    @Test func setAndGetLocations() {
        let view = GradientView()
        view.locations = [0.0, 0.5, 1.0]
        let got = view.locations
        #expect(got.count == 3)
        #expect(abs(got[0] - 0.0) <= 1e-6)
        #expect(abs(got[1] - 0.5) <= 1e-6)
        #expect(abs(got[2] - 1.0) <= 1e-6)
    }

    @Test func setLocationsWritesThroughToLayer() throws {
        let view = GradientView()
        view.locations = [0.25, 0.75]
        let layer = gradientLayer(of: view)
        let layerLocations = try #require(layer.locations)
        #expect(layerLocations.count == 2)
        #expect(abs(layerLocations[0].doubleValue - 0.25) <= 1e-6)
        #expect(abs(layerLocations[1].doubleValue - 0.75) <= 1e-6)
    }

    @Test func setEmptyLocationsRoundTrips() {
        let view = GradientView()
        view.locations = [0, 1]
        #expect(view.locations.count == 2)
        view.locations = []
        #expect(view.locations.isEmpty)
        #expect(gradientLayer(of: view).locations?.isEmpty ?? false)
    }

    @Test func locationsSingleElement() {
        let view = GradientView()
        view.locations = [0.42]
        let got = view.locations
        #expect(got.count == 1)
        #expect(abs(got[0] - 0.42) <= 1e-6)
    }

    @Test func locationsPreservesOrderAndValues() {
        let view = GradientView()
        let input: [CGFloat] = [0.1, 0.2, 0.35, 0.5, 0.9, 1.0]
        view.locations = input
        let got = view.locations
        #expect(got.count == input.count)
        for (a, b) in zip(got, input) {
            #expect(abs(a - b) <= 1e-6)
        }
    }

    @Test func locationsNegativeAndAboveOneArePreserved() {
        // The wrapper does no clamping; values pass straight through NSNumber.
        let view = GradientView()
        let input: [CGFloat] = [-0.5, 0.0, 1.5]
        view.locations = input
        let got = view.locations
        #expect(got.count == 3)
        #expect(abs(got[0] - (-0.5)) <= 1e-6)
        #expect(abs(got[1] - 0.0) <= 1e-6)
        #expect(abs(got[2] - 1.5) <= 1e-6)
    }

    @Test func locationsPreserveNonMonotonicAndExtremeFiniteValues() {
        // No sorting or clamping happens; even a descending, large-magnitude
        // finite sequence must round-trip element-for-element.
        let view = GradientView()
        let input: [CGFloat] = [1000, 0.5, -1000, 0]
        view.locations = input
        let got = view.locations
        #expect(got.count == input.count)
        for (a, b) in zip(got, input) {
            #expect(abs(a - b) <= 1e-3)
        }
    }

    @Test func locationsPreserveNaNAndInfinity() {
        // CGFloat(doubleValue) (the cgFloatValue helper) passes special values
        // through unchanged. NaN must compare via isNaN (NaN != NaN).
        let view = GradientView()
        let input: [CGFloat] = [.nan, .infinity, -.infinity]
        view.locations = input
        let got = view.locations
        #expect(got.count == 3)
        #expect(got[0].isNaN)
        #expect(got[1] == .infinity)
        #expect(got[2] == -.infinity)
    }

    @Test func locationsLargeArray() {
        let view = GradientView()
        let count = 100_000
        let input = (0..<count).map { CGFloat($0) / CGFloat(count) }
        view.locations = input
        let got = view.locations
        #expect(got.count == count)
        #expect(abs(got[0] - input[0]) <= 1e-6)
        #expect(abs(got[count / 2] - input[count / 2]) <= 1e-6)
        #expect(abs(got[count - 1] - input[count - 1]) <= 1e-6)
    }

    @Test(arguments: [
        CGFloat(0.0),
        CGFloat(0.000_001),
        CGFloat(0.333_333),
        CGFloat(0.5),
        CGFloat(1.0),
    ])
    func locationsRoundTripValue(_ value: CGFloat) throws {
        let view = GradientView()
        view.locations = [value]
        let got = try #require(view.locations.first)
        #expect(abs(got - value) <= 1e-6)
    }

    // MARK: - startPoint / endPoint

    @Test func startPointDefaultMatchesLayer() {
        let view = GradientView()
        // The wrapper must reflect whatever the layer's default startPoint is.
        #expect(view.startPoint == gradientLayer(of: view).startPoint)
    }

    @Test func endPointDefaultMatchesLayer() {
        let view = GradientView()
        // The wrapper must reflect whatever the layer's default endPoint is.
        #expect(view.endPoint == gradientLayer(of: view).endPoint)
    }

    @Test func setAndGetStartPoint() {
        let view = GradientView()
        let p = CGPoint(x: 0.0, y: 0.0)
        view.startPoint = p
        #expect(view.startPoint == p)
        #expect(gradientLayer(of: view).startPoint == p)
    }

    @Test func setAndGetEndPoint() {
        let view = GradientView()
        let p = CGPoint(x: 1.0, y: 1.0)
        view.endPoint = p
        #expect(view.endPoint == p)
        #expect(gradientLayer(of: view).endPoint == p)
    }

    @Test func startAndEndPointsAreIndependent() {
        let view = GradientView()
        let start = CGPoint(x: 0.2, y: 0.3)
        let end = CGPoint(x: 0.8, y: 0.9)
        view.startPoint = start
        view.endPoint = end
        #expect(view.startPoint == start)
        #expect(view.endPoint == end)
    }

    @Test func startPointReassignmentUpdatesLayer() {
        let view = GradientView()
        view.startPoint = CGPoint(x: 0.1, y: 0.2)
        view.startPoint = CGPoint(x: 0.7, y: 0.8)
        #expect(view.startPoint == CGPoint(x: 0.7, y: 0.8))
        #expect(gradientLayer(of: view).startPoint == CGPoint(x: 0.7, y: 0.8))
    }

    @Test(arguments: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 1, y: 1),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: -1, y: 2),          // out-of-[0,1] still passes through
        CGPoint(x: 0.25, y: 0.75),
    ])
    func startPointRoundTrip(_ p: CGPoint) {
        let view = GradientView()
        view.startPoint = p
        #expect(view.startPoint == p)
        #expect(gradientLayer(of: view).startPoint == p)
    }

    @Test(arguments: [
        CGPoint(x: 0, y: 0),
        CGPoint(x: 1, y: 1),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 2, y: -1),
        CGPoint(x: 0.1, y: 0.9),
    ])
    func endPointRoundTrip(_ p: CGPoint) {
        let view = GradientView()
        view.endPoint = p
        #expect(view.endPoint == p)
        #expect(gradientLayer(of: view).endPoint == p)
    }

    // MARK: - type

    @Test func typeDefaultIsAxial() {
        let view = GradientView()
        // Default CAGradientLayerType is .axial.
        #expect(view.type == .axial)
        #expect(view.type == gradientLayer(of: view).type)
    }

    @Test func setAndGetTypeAxial() {
        let view = GradientView()
        view.type = .axial
        #expect(view.type == .axial)
        #expect(gradientLayer(of: view).type == .axial)
    }

    @Test func setAndGetTypeRadial() {
        let view = GradientView()
        view.type = .radial
        #expect(view.type == .radial)
        #expect(gradientLayer(of: view).type == .radial)
    }

    @Test func setAndGetTypeConic() {
        let view = GradientView()
        view.type = .conic
        #expect(view.type == .conic)
        #expect(gradientLayer(of: view).type == .conic)
    }

    @Test func typeCanBeReassigned() {
        let view = GradientView()
        view.type = .radial
        #expect(view.type == .radial)
        view.type = .conic
        #expect(view.type == .conic)
        view.type = .axial
        #expect(view.type == .axial)
    }

    @Test func typeCustomRawValuePassesThrough() {
        // CAGradientLayerType is an NS_TYPED_ENUM over NSString. The wrapper
        // is a plain passthrough, so an arbitrary raw value survives the
        // round-trip even if it is not one of the named cases.
        let view = GradientView()
        let custom = CAGradientLayerType(rawValue: "swiftcodebook.customGradient")
        view.type = custom
        #expect(view.type == custom)
        #expect(view.type.rawValue == "swiftcodebook.customGradient")
        #expect(gradientLayer(of: view).type == custom)
    }

    @Test func typeRawValueMatchesKnownConstant() {
        // The named .axial case must expose the documented "axial" raw value.
        let view = GradientView()
        view.type = .axial
        #expect(view.type.rawValue == CAGradientLayerType.axial.rawValue)
    }

    // MARK: - Combined / integration

    @Test func fullConfigurationRoundTrips() {
        let view = GradientView()
        let colors: [UIColor] = [.red, .green, .blue]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        let start = CGPoint(x: 0.0, y: 0.0)
        let end = CGPoint(x: 1.0, y: 1.0)

        view.colors = colors
        view.locations = locations
        view.startPoint = start
        view.endPoint = end
        view.type = .radial

        #expect(view.colors.count == colors.count)
        for (a, b) in zip(view.colors, colors) { expectSameColor(a, b) }

        let gotLocations = view.locations
        #expect(gotLocations.count == locations.count)
        for (a, b) in zip(gotLocations, locations) { #expect(abs(a - b) <= 1e-6) }

        #expect(view.startPoint == start)
        #expect(view.endPoint == end)
        #expect(view.type == .radial)
    }

    @Test func propertiesAreIndependent() {
        // Mutating one property must not disturb the others.
        let view = GradientView()
        view.colors = [.red, .blue]
        view.locations = [0.0, 1.0]
        view.startPoint = CGPoint(x: 0.1, y: 0.2)
        view.endPoint = CGPoint(x: 0.9, y: 0.8)
        view.type = .conic

        // Change only colors.
        view.colors = [.green]
        #expect(view.colors.count == 1)
        #expect(view.locations.count == 2)
        #expect(view.startPoint == CGPoint(x: 0.1, y: 0.2))
        #expect(view.endPoint == CGPoint(x: 0.9, y: 0.8))
        #expect(view.type == .conic)
    }

    @Test func mutatingLocationsDoesNotDisturbColors() {
        // Cross-check the other direction of independence.
        let view = GradientView()
        view.colors = [.red, .green, .blue]
        view.locations = [0.0, 0.5, 1.0]
        view.locations = [0.1, 0.9]
        #expect(view.locations.count == 2)
        #expect(view.colors.count == 3)
    }

    @Test func twoViewsDoNotShareState() {
        let a = GradientView()
        let b = GradientView()
        a.colors = [.red]
        a.locations = [0, 1]
        a.startPoint = CGPoint(x: 0.1, y: 0.1)
        a.type = .radial
        // b must remain at its defaults.
        #expect(b.colors.isEmpty)
        #expect(b.locations.isEmpty)
        #expect(b.type == .axial)
        #expect(b.startPoint != CGPoint(x: 0.1, y: 0.1))
    }
}
