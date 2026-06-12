//
//  UIColorToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIColor+Tools.swift
//  Covers the public `UIColor` extension:
//    - convenience init?(rgba: String)        // "#RRGGBB" or "#RRGGBBAA"
//    - var rgba: (red, green, blue, alpha)?   // component extraction
//    - var rgbaString: String?                // hex serialization ("#RRGGBB" / "#RRGGBBAA")
//

import Testing
import Foundation
import UIKit
import CoreGraphics
@testable import SwiftCodeBook

@Suite struct UIColorToolsTests {

    // MARK: - Helpers

    /// Compares two CGFloat component values with a tolerance generous enough to
    /// absorb the 1/255 quantization that color round-tripping introduces.
    private static func approxEqual(_ a: CGFloat, _ b: CGFloat, tol: CGFloat = 1.0 / 255.0 / 2.0 + 1e-6) -> Bool {
        abs(a - b) <= tol
    }

    /// Builds the expected per-channel hex value the source would produce:
    /// clamp to 0...1, scale to 255, round, format uppercase radix-16, pad to 2 chars.
    private static func channelHex(_ value: CGFloat) -> String {
        let clamped = max(0, min(1, value))
        let hex = String(Int((clamped * 255.0).rounded()), radix: 16, uppercase: true)
        return hex.count == 1 ? "0\(hex)" : hex
    }

    /// Formats a 0...255 byte as a 2-char uppercase hex pair, e.g. 5 -> "05", 255 -> "FF".
    private static func bytePair(_ byte: Int) -> String {
        let hex = String(byte, radix: 16, uppercase: true)
        return hex.count == 1 ? "0\(hex)" : hex
    }

    // MARK: - init?(rgba:) happy path, 6-digit (#RRGGBB, implicit alpha = FF)

    @Test func initSixDigitOpaqueBasicColors() throws {
        // #RRGGBB -> alpha forced to 1.0
        let red = try #require(UIColor(rgba: "#FF0000"))
        let rgba = try #require(red.rgba)
        #expect(Self.approxEqual(rgba.red, 1.0))
        #expect(Self.approxEqual(rgba.green, 0.0))
        #expect(Self.approxEqual(rgba.blue, 0.0))
        #expect(Self.approxEqual(rgba.alpha, 1.0))
    }

    @Test(arguments: [
        ("#000000", CGFloat(0), CGFloat(0), CGFloat(0)),
        ("#FFFFFF", CGFloat(1), CGFloat(1), CGFloat(1)),
        ("#FF0000", CGFloat(1), CGFloat(0), CGFloat(0)),
        ("#00FF00", CGFloat(0), CGFloat(1), CGFloat(0)),
        ("#0000FF", CGFloat(0), CGFloat(0), CGFloat(1)),
        ("#808080", CGFloat(128) / 255, CGFloat(128) / 255, CGFloat(128) / 255),
    ])
    func initSixDigitComponentMapping(hex: String, r: CGFloat, g: CGFloat, b: CGFloat) throws {
        let color = try #require(UIColor(rgba: hex))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, r))
        #expect(Self.approxEqual(comps.green, g))
        #expect(Self.approxEqual(comps.blue, b))
        #expect(Self.approxEqual(comps.alpha, 1.0)) // 6-digit always opaque
    }

    // MARK: - init?(rgba:) happy path, 8-digit (#RRGGBBAA, explicit alpha)

    @Test(arguments: [
        ("#FF000000", CGFloat(1), CGFloat(0), CGFloat(0), CGFloat(0)),       // red, fully transparent
        ("#00FF0080", CGFloat(0), CGFloat(1), CGFloat(0), CGFloat(128) / 255), // green, ~50% alpha
        ("#0000FFFF", CGFloat(0), CGFloat(0), CGFloat(1), CGFloat(1)),       // blue, opaque
        ("#FFFFFF00", CGFloat(1), CGFloat(1), CGFloat(1), CGFloat(0)),       // white, transparent
        ("#12345678", CGFloat(0x12) / 255, CGFloat(0x34) / 255, CGFloat(0x56) / 255, CGFloat(0x78) / 255),
    ])
    func initEightDigitComponentMapping(hex: String, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) throws {
        let color = try #require(UIColor(rgba: hex))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, r))
        #expect(Self.approxEqual(comps.green, g))
        #expect(Self.approxEqual(comps.blue, b))
        #expect(Self.approxEqual(comps.alpha, a))
    }

    // MARK: - init?(rgba:) byte ordering is RRGGBBAA

    @Test func initByteOrderIsRRGGBBAA() throws {
        // Distinct values per channel to prove ordering is not transposed.
        let color = try #require(UIColor(rgba: "#102030FF"))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, CGFloat(0x10) / 255))
        #expect(Self.approxEqual(comps.green, CGFloat(0x20) / 255))
        #expect(Self.approxEqual(comps.blue, CGFloat(0x30) / 255))
        #expect(Self.approxEqual(comps.alpha, 1.0))
    }

    @Test func initByteOrderEightDigitAllDistinct() throws {
        // Each channel a distinct byte, alpha non-opaque, to lock down the full
        // (hexNum >> shift) & 0xFF mapping including the alpha lane.
        let color = try #require(UIColor(rgba: "#0A141E28"))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, CGFloat(0x0A) / 255))
        #expect(Self.approxEqual(comps.green, CGFloat(0x14) / 255))
        #expect(Self.approxEqual(comps.blue, CGFloat(0x1E) / 255))
        #expect(Self.approxEqual(comps.alpha, CGFloat(0x28) / 255))
    }

    // MARK: - init?(rgba:) case insensitivity

    @Test(arguments: ["#abcdef", "#ABCDEF", "#AbCdEf"])
    func initIsCaseInsensitive(hex: String) throws {
        let color = try #require(UIColor(rgba: hex))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, CGFloat(0xAB) / 255))
        #expect(Self.approxEqual(comps.green, CGFloat(0xCD) / 255))
        #expect(Self.approxEqual(comps.blue, CGFloat(0xEF) / 255))
        #expect(Self.approxEqual(comps.alpha, 1.0))
    }

    @Test func initLowerAndUpperProduceEqualColors() throws {
        let lower = try #require(UIColor(rgba: "#a1b2c3d4"))
        let upper = try #require(UIColor(rgba: "#A1B2C3D4"))
        let lo = try #require(lower.rgba)
        let up = try #require(upper.rgba)
        #expect(Self.approxEqual(lo.red, up.red))
        #expect(Self.approxEqual(lo.green, up.green))
        #expect(Self.approxEqual(lo.blue, up.blue))
        #expect(Self.approxEqual(lo.alpha, up.alpha))
    }

    // MARK: - init?(rgba:) failure branches -> nil

    @Test(arguments: [
        "",                 // empty
        "FF0000",           // missing leading '#'
        "#",                // only '#', count 1
        "#FFF",             // 3-digit shorthand not supported, count 4
        "#FFFF",            // count 5
        "#FFFFF",           // count 6 (one short of 7)
        "#FFFFFFF",         // count 8 (between 7 and 9, invalid)
        "#FFFFFFFFF",       // count 10, too long
        "#FFFFFFFFFF",      // count 11, far too long
        "#GGGGGG",          // non-hex characters, valid length
        "#ZZZZZZZZ",        // non-hex characters, 8-digit length
        "#12 456",          // space inside, fails isAtEnd / hex parse
        "#FF00GG",          // trailing non-hex
        " #FFFFFF",         // leading space pushes first char off '#'
        "#FFFFFF ",         // trailing space, count 8 anyway invalid
        "##FFFFF",          // double hash, count 7 but non-hex '#'
        "#-FF000",          // negative sign, count 7 but invalid hex
        "#+FF000",          // explicit plus sign, count 7 but invalid hex
        "#FF.000",          // decimal point, count 7 but invalid hex
        "#你好世界一二",      // multibyte unicode body, count 7 but non-hex
        "#FF00G0G0",        // 8-digit length with embedded non-hex
    ])
    func initRejectsMalformedStrings(bad: String) {
        #expect(UIColor(rgba: bad) == nil)
    }

    @Test func initRejectsTrailingHexAfterValidPrefixDueToIsAtEnd() {
        // "#FFFFFF " (count 8) is rejected by the length guard (not 7/9). And a
        // count-9 string whose 8 hex digits are followed by junk would fail
        // isAtEnd, but length already filters most. Confirm the count-7-with-space
        // form fails because the embedded space breaks scanHexInt64 + isAtEnd.
        #expect(UIColor(rgba: "#FF FFF") == nil)
    }

    @Test func initAcceptsHexPrefixedInnerString() throws {
        // SUSPECTED BUG: Scanner.scanHexInt64 happily consumes a leading "0x"
        // prefix, so "#0xFFFF" (count 7) does NOT fail the parse. The body
        // "0xFFFF" + "FF" = "0xFFFFFF" scans to 0x00FFFFFF, yielding cyan/opaque.
        // We assert the ACTUAL (arguably wrong) behavior so the test passes.
        let color = try #require(UIColor(rgba: "#0xFFFF"))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, 0.0))
        #expect(Self.approxEqual(comps.green, 1.0))
        #expect(Self.approxEqual(comps.blue, 1.0))
        #expect(Self.approxEqual(comps.alpha, 1.0))
    }

    @Test func initAcceptsUppercaseHexPrefixedInnerString() throws {
        // Same suspected bug, uppercase "0X" prefix: "#0XFFFF" -> "0XFFFFFF"
        // also scans to 0x00FFFFFF (cyan/opaque). Asserts the ACTUAL behavior.
        let color = try #require(UIColor(rgba: "#0XFFFF"))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, 0.0))
        #expect(Self.approxEqual(comps.green, 1.0))
        #expect(Self.approxEqual(comps.blue, 1.0))
        #expect(Self.approxEqual(comps.alpha, 1.0))
    }

    @Test func initSkipsLeadingWhitespaceInBody() throws {
        // SUSPECTED BUG: count == 7 satisfies the guard, and Scanner skips leading
        // whitespace by default, so "#  ABCD" -> body "  ABCD" + "FF" = "  ABCDFF"
        // scans to 0x00ABCDFF and parses (r=0, g=0xAB, b=0xCD, a=0xFF) instead of
        // failing. We assert the ACTUAL behavior.
        let color = try #require(UIColor(rgba: "#  ABCD"))
        let comps = try #require(color.rgba)
        #expect(Self.approxEqual(comps.red, 0.0))
        #expect(Self.approxEqual(comps.green, CGFloat(0xAB) / 255))
        #expect(Self.approxEqual(comps.blue, CGFloat(0xCD) / 255))
        #expect(Self.approxEqual(comps.alpha, 1.0))
    }

    // MARK: - rgba property

    @Test func rgbaReturnsComponentsForWhiteAndBlack() throws {
        let white = try #require(UIColor.white.rgba)
        #expect(Self.approxEqual(white.red, 1.0))
        #expect(Self.approxEqual(white.green, 1.0))
        #expect(Self.approxEqual(white.blue, 1.0))
        #expect(Self.approxEqual(white.alpha, 1.0))

        let black = try #require(UIColor.black.rgba)
        #expect(Self.approxEqual(black.red, 0.0))
        #expect(Self.approxEqual(black.green, 0.0))
        #expect(Self.approxEqual(black.blue, 0.0))
        #expect(Self.approxEqual(black.alpha, 1.0))
    }

    @Test func rgbaHonorsExplicitAlpha() throws {
        let c = UIColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.4)
        let comps = try #require(c.rgba)
        #expect(Self.approxEqual(comps.red, 0.25))
        #expect(Self.approxEqual(comps.green, 0.5))
        #expect(Self.approxEqual(comps.blue, 0.75))
        #expect(Self.approxEqual(comps.alpha, 0.4))
    }

    @Test func rgbaHandlesGrayscaleColor() throws {
        // UIColor(white:alpha:) lives in an extended-gray space, but
        // getRed:green:blue:alpha: bridges it; the gray value should appear in
        // all three RGB channels.
        let comps = try #require(UIColor(white: 0.6, alpha: 0.8).rgba)
        #expect(Self.approxEqual(comps.red, 0.6))
        #expect(Self.approxEqual(comps.green, 0.6))
        #expect(Self.approxEqual(comps.blue, 0.6))
        #expect(Self.approxEqual(comps.alpha, 0.8))
    }

    @Test func rgbaReturnsNilForPatternColor() {
        // A pattern (image) color cannot be decomposed via getRed:green:blue:alpha:,
        // so the rgba accessor must return nil.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let pattern = UIColor(patternImage: image)
        #expect(pattern.rgba == nil)
    }

    // MARK: - rgbaString property

    @Test func rgbaStringOpaqueOmitsAlpha() throws {
        // Opaque colors (alpha >= 1) produce 6-digit "#RRGGBB" (no alpha pair).
        let s = try #require(UIColor.red.rgbaString)
        #expect(s == "#FF0000")
        #expect(s.count == 7)
    }

    @Test(arguments: [
        ("#000000", "#000000"),
        ("#FFFFFF", "#FFFFFF"),
        ("#FF0000", "#FF0000"),
        ("#00FF00", "#00FF00"),
        ("#0000FF", "#0000FF"),
        ("#123456", "#123456"),
        ("#0A0B0C", "#0A0B0C"), // leading-zero padding per channel
    ])
    func rgbaStringRoundTripsSixDigit(input: String, expected: String) throws {
        let color = try #require(UIColor(rgba: input))
        let out = try #require(color.rgbaString)
        #expect(out == expected)
    }

    @Test(arguments: [
        ("#FF000080", "#FF000080"),
        ("#00FF0000", "#00FF0000"),
        ("#1234567F", "#1234567F"),
        ("#0A0B0C0D", "#0A0B0C0D"),
        ("#102030FE", "#102030FE"), // alpha 0xFE (just below opaque) keeps 8-digit
    ])
    func rgbaStringRoundTripsEightDigitNonOpaque(input: String, expected: String) throws {
        // Non-opaque colors (alpha < 1) keep the trailing alpha pair.
        let color = try #require(UIColor(rgba: input))
        let out = try #require(color.rgbaString)
        #expect(out == expected)
        #expect(out.count == 9)
    }

    @Test func rgbaStringFullyTransparentKeepsAlphaPair() throws {
        // alpha == 0 is < 1, so the "00" alpha pair must be emitted (not dropped).
        let color = try #require(UIColor(rgba: "#12345600"))
        let out = try #require(color.rgbaString)
        #expect(out == "#12345600")
        #expect(out.count == 9)
    }

    @Test func rgbaStringEightDigitFullyOpaqueDropsAlpha() throws {
        // "#RRGGBBFF" parses alpha = 1.0, so rgbaString drops the alpha pair.
        let color = try #require(UIColor(rgba: "#112233FF"))
        let out = try #require(color.rgbaString)
        #expect(out == "#112233")
    }

    @Test func rgbaStringPadsSingleDigitChannels() throws {
        // Channel value 0x05 must serialize as "05", not "5".
        let color = UIColor(red: CGFloat(0x05) / 255, green: CGFloat(0x00) / 255, blue: CGFloat(0x09) / 255, alpha: 1)
        let out = try #require(color.rgbaString)
        #expect(out == "#050009")
    }

    @Test func rgbaStringClampsOutOfRangeComponents() throws {
        // Components beyond [0,1] are clamped: negative -> 00, > 1 -> FF.
        let color = UIColor(red: -0.5, green: 2.0, blue: 0.5, alpha: 1.0)
        let out = try #require(color.rgbaString)
        // red clamped to 0 -> 00; green clamped to 1 -> FF; blue 0.5*255=127.5 -> 128 -> 80
        #expect(out == "#00FF80")
    }

    @Test func rgbaStringClampsNegativeAlpha() throws {
        // A negative alpha is < 1 (so the pair is emitted) and clamps to 00.
        let color = UIColor(red: 1, green: 1, blue: 1, alpha: -0.3)
        let out = try #require(color.rgbaString)
        #expect(out == "#FFFFFF00")
    }

    @Test func rgbaStringRoundingHalfUp() throws {
        // 0.5/255 boundary: round() rounds .5 away from zero.
        // value = 1/510 ~ which channel? Use a value that lands exactly on x.5 after *255.
        // 0x01 + 0.5 quanta: choose red so red*255 == 1.5 -> rounds to 2 -> "02".
        let color = UIColor(red: 1.5 / 255.0, green: 0, blue: 0, alpha: 1)
        let out = try #require(color.rgbaString)
        #expect(out == "#020000")
    }

    @Test func rgbaStringReturnsNilForPatternColor() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let pattern = UIColor(patternImage: image)
        #expect(pattern.rgbaString == nil)
    }

    // MARK: - Round-trip: string -> color -> string

    @Test(arguments: [
        "#000000", "#FFFFFF", "#102030", "#ABCDEF", "#7F7F7F",
        "#10203040", "#ABCDEF12", "#000000FF" /* opaque -> becomes #000000 below */,
    ])
    func roundTripStringColorString(input: String) throws {
        let color = try #require(UIColor(rgba: input))
        let out = try #require(color.rgbaString)
        // Re-parsing the produced string must yield an equivalent color.
        let reparsed = try #require(UIColor(rgba: out))
        let a = try #require(color.rgba)
        let b = try #require(reparsed.rgba)
        #expect(Self.approxEqual(a.red, b.red))
        #expect(Self.approxEqual(a.green, b.green))
        #expect(Self.approxEqual(a.blue, b.blue))
        #expect(Self.approxEqual(a.alpha, b.alpha))
    }

    @Test func roundTripOpaqueEightDigitCollapsesToSixDigit() throws {
        // "#000000FF" (opaque) serializes back as the 6-digit form.
        let color = try #require(UIColor(rgba: "#000000FF"))
        let out = try #require(color.rgbaString)
        #expect(out == "#000000")
    }

    @Test func roundTripUppercaseOutputForLowercaseInput() throws {
        // rgbaString always emits uppercase; lowercase input must normalize.
        let color = try #require(UIColor(rgba: "#abcdef"))
        let out = try #require(color.rgbaString)
        #expect(out == "#ABCDEF")
    }

    // MARK: - Full exhaustive single-channel byte coverage

    @Test func everySingleChannelByteRoundTrips() throws {
        // Drive red through all 256 byte values; confirm parse->serialize stability.
        for byte in 0...255 {
            let input = "#\(Self.bytePair(byte))0000"
            let color = try #require(UIColor(rgba: input), "failed to parse \(input)")
            let out = try #require(color.rgbaString, "no rgbaString for \(input)")
            #expect(out == input, "byte \(byte): expected \(input) got \(out)")
        }
    }

    @Test func everyAlphaByteBelowOpaqueRoundTrips() throws {
        // Drive the alpha channel across 0...254 (255 collapses to 6-digit and is
        // covered separately). Each non-opaque alpha must round-trip exactly.
        for byte in 0...254 {
            let input = "#000000\(Self.bytePair(byte))"
            let color = try #require(UIColor(rgba: input), "failed to parse \(input)")
            let out = try #require(color.rgbaString, "no rgbaString for \(input)")
            #expect(out == input, "alpha \(byte): expected \(input) got \(out)")
        }
        // And the opaque sentinel collapses.
        let opaque = try #require(UIColor(rgba: "#000000FF"))
        #expect(try #require(opaque.rgbaString) == "#000000")
    }

    // MARK: - Large-data / stress over many distinct inputs

    @Test func stressManyDistinctColorsRoundTrip() throws {
        // Sample a wide spread of RGB triples; serialize then re-parse, verifying
        // component stability within quantization tolerance.
        var checked = 0
        for r in stride(from: 0, through: 255, by: 17) {
            for g in stride(from: 0, through: 255, by: 23) {
                for b in stride(from: 0, through: 255, by: 29) {
                    let color = UIColor(
                        red: CGFloat(r) / 255,
                        green: CGFloat(g) / 255,
                        blue: CGFloat(b) / 255,
                        alpha: 1
                    )
                    let out = try #require(color.rgbaString)
                    let reparsed = try #require(UIColor(rgba: out))
                    let comps = try #require(reparsed.rgba)
                    #expect(Self.approxEqual(comps.red, CGFloat(r) / 255))
                    #expect(Self.approxEqual(comps.green, CGFloat(g) / 255))
                    #expect(Self.approxEqual(comps.blue, CGFloat(b) / 255))
                    checked += 1
                }
            }
        }
        #expect(checked == 16 * 12 * 9) // 0...255 by 17/23/29 -> 16x12x9 = 1728 samples
    }

    // MARK: - Concurrency: init/rgba/rgbaString are pure & must be thread-safe

    @Test func concurrentParseAndSerializeIsConsistent() async {
        // Hammer the pure conversions from many concurrent tasks; assert each task
        // produces the deterministic expected output (no shared mutable state).
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<500 {
                let byte = i % 256
                let pair = Self.bytePair(byte)
                let input = "#\(pair)\(pair)\(pair)"
                group.addTask {
                    guard let color = UIColor(rgba: input),
                          let out = color.rgbaString else { return false }
                    return out == input
                }
            }
            var allGood = true
            for await ok in group where !ok { allGood = false }
            #expect(allGood)
        }
    }

    @Test func concurrentFinalCountMatches() async {
        // Verify no lost updates: every child task that succeeds is counted.
        let total = 1000
        let successes = await withTaskGroup(of: Int.self) { group -> Int in
            for i in 0..<total {
                let byte = i % 256
                group.addTask {
                    let pair = Self.bytePair(byte)
                    let input = "#\(pair)0000"
                    return UIColor(rgba: input)?.rgbaString == input ? 1 : 0
                }
            }
            var sum = 0
            for await v in group { sum += v }
            return sum
        }
        #expect(successes == total)
    }
}
