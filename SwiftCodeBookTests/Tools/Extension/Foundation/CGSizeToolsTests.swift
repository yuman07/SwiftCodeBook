//
//  CGSizeToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for CGSize+Tools.swift
//  Source under test:
//    SwiftCodeBook/Source/Tools/Extension/Foundation/CGSize+Tools.swift
//
//  Covers the CGSize helpers:
//    static one, isValid, validSelfOrOne
//  with emphasis on floating-point boundary cases (zero, negative, NaN,
//  +/- infinity, sub-normal, and very large finite magnitudes).
//

import Testing
import Foundation
import CoreGraphics
@testable import SwiftCodeBook

@Suite struct CGSizeToolsTests {

    // MARK: - one

    @Test func oneHasUnitWidthAndHeight() {
        let one = CGSize.one
        #expect(one.width == 1)
        #expect(one.height == 1)
        #expect(one == CGSize(width: 1, height: 1))
    }

    @Test func oneIsItselfValid() {
        #expect(CGSize.one.isValid)
    }

    // `one` is a computed property; each access yields an independent, equal value.
    @Test func oneIsStableAcrossAccesses() {
        #expect(CGSize.one == CGSize.one)
    }

    // MARK: - isValid: happy path

    @Test func isValidForPositiveFiniteSize() {
        #expect(CGSize(width: 100, height: 200).isValid)
        #expect(CGSize(width: 1, height: 1).isValid)
        #expect(CGSize(width: 0.5, height: 0.25).isValid)
    }

    // The smallest representable positive magnitude is still > 0 and finite.
    @Test func isValidForSubnormalPositiveDimensions() {
        let tiny = CGFloat.leastNonzeroMagnitude
        #expect(CGSize(width: tiny, height: tiny).isValid)
    }

    @Test func isValidForVeryLargeFiniteDimensions() {
        let big = CGFloat.greatestFiniteMagnitude
        #expect(CGSize(width: big, height: big).isValid)
    }

    // MARK: - isValid: zero boundaries

    @Test func isInvalidForZeroSize() {
        #expect(!CGSize.zero.isValid)
        #expect(!CGSize(width: 0, height: 0).isValid)
    }

    // width > 0 is strict, so a zero in either dimension is invalid.
    @Test func isInvalidWhenEitherDimensionIsZero() {
        #expect(!CGSize(width: 0, height: 10).isValid)
        #expect(!CGSize(width: 10, height: 0).isValid)
    }

    // Negative zero is not greater than zero, so it is treated as invalid.
    @Test func isInvalidForNegativeZero() {
        #expect(!CGSize(width: -0.0, height: 10).isValid)
        #expect(!CGSize(width: 10, height: -0.0).isValid)
        #expect(!CGSize(width: -0.0, height: -0.0).isValid)
    }

    // MARK: - isValid: negative boundaries

    @Test func isInvalidForNegativeDimensions() {
        #expect(!CGSize(width: -1, height: 10).isValid)
        #expect(!CGSize(width: 10, height: -1).isValid)
        #expect(!CGSize(width: -1, height: -1).isValid)
        #expect(!CGSize(width: -0.0001, height: 5).isValid)
    }

    @Test func isInvalidForLeastNegativeMagnitude() {
        let tinyNegative = -CGFloat.leastNonzeroMagnitude
        #expect(!CGSize(width: tinyNegative, height: 10).isValid)
        #expect(!CGSize(width: 10, height: tinyNegative).isValid)
    }

    // MARK: - isValid: NaN boundaries

    @Test func isInvalidForNaNDimensions() {
        let nan = CGFloat.nan
        #expect(!CGSize(width: nan, height: 10).isValid)
        #expect(!CGSize(width: 10, height: nan).isValid)
        #expect(!CGSize(width: nan, height: nan).isValid)
    }

    @Test func isInvalidForSignalingNaN() {
        let snan = CGFloat.signalingNaN
        #expect(!CGSize(width: snan, height: 10).isValid)
        #expect(!CGSize(width: 10, height: snan).isValid)
    }

    // MARK: - isValid: infinity boundaries

    @Test func isInvalidForPositiveInfinity() {
        let inf = CGFloat.infinity
        #expect(!CGSize(width: inf, height: 10).isValid)
        #expect(!CGSize(width: 10, height: inf).isValid)
        #expect(!CGSize(width: inf, height: inf).isValid)
    }

    @Test func isInvalidForNegativeInfinity() {
        let negInf = -CGFloat.infinity
        #expect(!CGSize(width: negInf, height: 10).isValid)
        #expect(!CGSize(width: 10, height: negInf).isValid)
        #expect(!CGSize(width: negInf, height: negInf).isValid)
    }

    // A finite-but-positive width paired with a non-finite height stays invalid:
    // both dimensions must independently pass.
    @Test func isInvalidWhenOnlyOneDimensionIsFiniteAndPositive() {
        #expect(!CGSize(width: 50, height: CGFloat.nan).isValid)
        #expect(!CGSize(width: 50, height: CGFloat.infinity).isValid)
        #expect(!CGSize(width: CGFloat.nan, height: 50).isValid)
        #expect(!CGSize(width: CGFloat.infinity, height: 50).isValid)
    }

    // MARK: - validSelfOrOne: passthrough for valid sizes

    @Test func validSelfOrOneReturnsSelfWhenValid() {
        let size = CGSize(width: 320, height: 480)
        #expect(size.validSelfOrOne == size)
    }

    @Test func validSelfOrOneReturnsSelfForSubnormalPositive() {
        let tiny = CGSize(width: CGFloat.leastNonzeroMagnitude, height: CGFloat.leastNonzeroMagnitude)
        #expect(tiny.validSelfOrOne == tiny)
    }

    @Test func validSelfOrOneReturnsSelfForOne() {
        #expect(CGSize.one.validSelfOrOne == CGSize.one)
    }

    // MARK: - validSelfOrOne: fallback to .one for invalid sizes

    @Test func validSelfOrOneReturnsOneForZero() {
        #expect(CGSize.zero.validSelfOrOne == .one)
    }

    @Test func validSelfOrOneReturnsOneForPartialZero() {
        #expect(CGSize(width: 0, height: 100).validSelfOrOne == .one)
        #expect(CGSize(width: 100, height: 0).validSelfOrOne == .one)
    }

    @Test func validSelfOrOneReturnsOneForNegative() {
        #expect(CGSize(width: -10, height: -20).validSelfOrOne == .one)
        #expect(CGSize(width: -10, height: 20).validSelfOrOne == .one)
        #expect(CGSize(width: 10, height: -20).validSelfOrOne == .one)
    }

    @Test func validSelfOrOneReturnsOneForNaN() {
        #expect(CGSize(width: CGFloat.nan, height: CGFloat.nan).validSelfOrOne == .one)
        #expect(CGSize(width: CGFloat.nan, height: 10).validSelfOrOne == .one)
        #expect(CGSize(width: 10, height: CGFloat.nan).validSelfOrOne == .one)
    }

    @Test func validSelfOrOneReturnsOneForInfinity() {
        #expect(CGSize(width: CGFloat.infinity, height: CGFloat.infinity).validSelfOrOne == .one)
        #expect(CGSize(width: -CGFloat.infinity, height: 10).validSelfOrOne == .one)
        #expect(CGSize(width: 10, height: CGFloat.infinity).validSelfOrOne == .one)
    }

    // The returned fallback must be exactly CGSize.one, not merely "some valid size".
    @Test func validSelfOrOneFallbackIsAlwaysValid() {
        let invalidSizes: [CGSize] = [
            .zero,
            CGSize(width: -1, height: -1),
            CGSize(width: CGFloat.nan, height: 1),
            CGSize(width: 1, height: CGFloat.infinity),
            CGSize(width: 0, height: 0),
            CGSize(width: -0.0, height: -0.0),
        ]
        for size in invalidSizes {
            let result = size.validSelfOrOne
            #expect(result == .one)
            #expect(result.isValid)
        }
    }
}
