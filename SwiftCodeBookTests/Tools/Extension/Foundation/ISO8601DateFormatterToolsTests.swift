//
//  ISO8601DateFormatterToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/ISO8601DateFormatter+Tools.swift
//
//  The extension exposes two static convenience APIs on ISO8601DateFormatter:
//    - ISO8601DateFormatter.string(from:options:)   (default options: .withTimeZone | .withFractionalSeconds)
//    - ISO8601DateFormatter.date(from:)
//
//  Internally it builds a fixed set of 4 cached formatters keyed by the two
//  "optional" flags (.withTimeZone, .withFractionalSeconds) on top of a fixed
//  `basic` option set (full date+time with dash / colon separators). The private
//  `formatters` / `optionals` / `basic` constants are exercised indirectly via the
//  two public functions.
//
//  Behaviour was verified against the real ISO8601DateFormatter on the platform:
//    basic                  -> "2023-11-14T22:13:20"
//    +withTimeZone          -> "2023-11-14T22:13:20Z"
//    +withFractionalSeconds -> "2023-11-14T22:13:20.500"
//    +both                  -> "2023-11-14T22:13:20.500Z"
//
//  All assertions use absolute epoch seconds so they are independent of the
//  simulator's locale / time zone (ISO8601DateFormatter renders in UTC / 'Z').
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct ISO8601DateFormatterToolsTests {

    // MARK: - Reference values

    // 2023-11-14T22:13:20.500Z  ==  1_700_000_000.5 seconds since 1970.
    private static let epoch = 1_700_000_000.5
    private static let referenceDate = Date(timeIntervalSince1970: epoch)

    // Whole-second variant: 2023-11-14T22:13:20Z == 1_700_000_000.
    private static let wholeSecondDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static let bothOptions: ISO8601DateFormatter.Options = [.withTimeZone, .withFractionalSeconds]

    // Tolerance for fractional comparisons (formatter renders milliseconds).
    private static let tol = 0.0011

    // MARK: - string(from:options:) — all four option combinations

    @Test func stringWithBothOptionsRendersTimeZoneAndFractionalSeconds() {
        let s = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withTimeZone, .withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:20.500Z")
    }

    @Test func stringWithEmptyOptionsRendersBasicNoZoneNoFraction() {
        let s = ISO8601DateFormatter.string(from: Self.referenceDate, options: [])
        #expect(s == "2023-11-14T22:13:20")
    }

    @Test func stringWithOnlyTimeZoneAppendsZButNoFraction() {
        let s = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withTimeZone])
        #expect(s == "2023-11-14T22:13:20Z")
    }

    @Test func stringWithOnlyFractionalSecondsAppendsFractionButNoZone() {
        let s = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:20.500")
    }

    /// Parameterised cross-check of all four tracked-option combinations in one place,
    /// so a regression in the index-encoding (`1 << idx`) for any combo is caught.
    @Test(arguments: [
        ([] as ISO8601DateFormatter.Options, "2023-11-14T22:13:20"),
        ([.withTimeZone], "2023-11-14T22:13:20Z"),
        ([.withFractionalSeconds], "2023-11-14T22:13:20.500"),
        ([.withTimeZone, .withFractionalSeconds], "2023-11-14T22:13:20.500Z"),
    ] as [(ISO8601DateFormatter.Options, String)])
    func stringAllTrackedCombinations(_ options: ISO8601DateFormatter.Options, _ expected: String) {
        #expect(ISO8601DateFormatter.string(from: Self.referenceDate, options: options) == expected)
    }

    // MARK: - Default argument

    @Test func stringDefaultArgumentMatchesBothOptions() {
        // The default options are [.withTimeZone, .withFractionalSeconds].
        let defaulted = ISO8601DateFormatter.string(from: Self.referenceDate)
        let explicit = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withTimeZone, .withFractionalSeconds])
        #expect(defaulted == explicit)
        #expect(defaulted == "2023-11-14T22:13:20.500Z")
    }

    // MARK: - Option index encoding edge cases

    @Test func unrelatedOptionsAreIgnoredAndTreatedAsBasic() {
        // Only .withTimeZone / .withFractionalSeconds participate in index selection.
        // Any other option (e.g. .withWeekOfYear) does not change the chosen formatter,
        // so the output equals the empty-options (basic) rendering.
        let withUnrelated = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withWeekOfYear])
        let basic = ISO8601DateFormatter.string(from: Self.referenceDate, options: [])
        #expect(withUnrelated == basic)
        #expect(withUnrelated == "2023-11-14T22:13:20")
    }

    @Test func extraOptionsAlongsideTrackedOptionsDoNotDisturbSelection() {
        // Tracked options still resolve correctly even when bundled with untracked ones.
        let s = ISO8601DateFormatter.string(
            from: Self.referenceDate,
            options: [.withTimeZone, .withFractionalSeconds, .withWeekOfYear, .withSpaceBetweenDateAndTime]
        )
        #expect(s == "2023-11-14T22:13:20.500Z")
    }

    @Test func trackedOptionsSelectIndependentBits() {
        // .withTimeZone is index 0 (bit 1), .withFractionalSeconds is index 1 (bit 2);
        // each must select a *distinct* cached formatter. Verify the two single-bit
        // selections differ from each other and from the basic/both renderings.
        let tzOnly = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withTimeZone])
        let fracOnly = ISO8601DateFormatter.string(from: Self.referenceDate, options: [.withFractionalSeconds])
        let basic = ISO8601DateFormatter.string(from: Self.referenceDate, options: [])
        let both = ISO8601DateFormatter.string(from: Self.referenceDate, options: Self.bothOptions)
        #expect(Set([tzOnly, fracOnly, basic, both]).count == 4)
        #expect(tzOnly != fracOnly)
        #expect(tzOnly.hasSuffix("Z") && !tzOnly.contains("."))
        #expect(fracOnly.contains(".") && !fracOnly.hasSuffix("Z"))
    }

    // MARK: - Whole-second dates (no fractional part to render)

    @Test func stringWholeSecondWithFractionStillRendersZeroMillis() {
        let s = ISO8601DateFormatter.string(from: Self.wholeSecondDate, options: [.withTimeZone, .withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:20.000Z")
    }

    @Test func stringWholeSecondBasic() {
        let s = ISO8601DateFormatter.string(from: Self.wholeSecondDate, options: [])
        #expect(s == "2023-11-14T22:13:20")
    }

    // MARK: - Special / extreme dates

    @Test func stringReferenceDate2001() {
        // timeIntervalSinceReferenceDate == 0  ->  2001-01-01T00:00:00Z
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSinceReferenceDate: 0), options: Self.bothOptions)
        #expect(s == "2001-01-01T00:00:00.000Z")
    }

    @Test func stringEpoch1970() {
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: 0), options: Self.bothOptions)
        #expect(s == "1970-01-01T00:00:00.000Z")
    }

    @Test func stringNegativeEpochBefore1970() {
        // -1000 seconds before 1970-01-01T00:00:00Z == 1969-12-31T23:43:20Z
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: -1000), options: [.withTimeZone])
        #expect(s == "1969-12-31T23:43:20Z")
    }

    @Test func stringNegativeEpochWithFractionalSeconds() {
        // -1000.5s before epoch -> 1969-12-31T23:43:19.500Z (fractional part of a
        // negative interval still renders forward toward the displayed second).
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: -1000.5), options: Self.bothOptions)
        #expect(s == "1969-12-31T23:43:19.500Z")
    }

    @Test func stringDistantPastAndFutureExactRendering() {
        // ISO8601DateFormatter renders these stable, locale-independent UTC strings.
        let past = ISO8601DateFormatter.string(from: .distantPast, options: Self.bothOptions)
        let future = ISO8601DateFormatter.string(from: .distantFuture, options: Self.bothOptions)
        #expect(past == "0001-01-01T00:00:00.000Z")
        #expect(future == "4001-01-01T00:00:00.000Z")
    }

    @Test func stringFractionalSecondsTruncateToMilliseconds() {
        // 1_700_000_000.123456 -> milliseconds ".123"
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: 1_700_000_000.123456), options: [.withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:20.123")
    }

    @Test func stringSubMillisecondRoundsDownToZero() {
        // 0.0001s is below the millisecond resolution and renders as ".000".
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: 1_700_000_000.0001), options: [.withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:20.000")
    }

    @Test func stringFractionalSecondsRoundCarriesIntoNextSecond() {
        // 0.9999s rounds up past the millisecond grid and carries into the next whole
        // second: ...20.9999 -> ...21.000 (documenting the platform rounding behaviour).
        let s = ISO8601DateFormatter.string(from: Date(timeIntervalSince1970: 1_700_000_000.9999), options: [.withFractionalSeconds])
        #expect(s == "2023-11-14T22:13:21.000")
    }

    // MARK: - date(from:) happy paths

    @Test func parseFullFractionalZuluString() throws {
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20.500Z"))
        #expect(abs(date.timeIntervalSince1970 - 1_700_000_000.5) < Self.tol)
    }

    @Test func parseZuluWholeSecondString() throws {
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20Z"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test func parseStringWithoutTimeZoneAssumesUTC() throws {
        // No 'Z' / offset -> the basic formatter parses it as UTC on this platform.
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test func parseStringWithoutTimeZoneButWithFraction() throws {
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20.500"))
        #expect(abs(date.timeIntervalSince1970 - 1_700_000_000.5) < Self.tol)
    }

    @Test func parsePositiveUTCOffset() throws {
        // +08:00 means local clock is 8h ahead of UTC, so subtract 8h (28800s).
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20+08:00"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000 - 28_800)
    }

    @Test func parseNegativeUTCOffset() throws {
        // -05:00 means local clock is 5h behind UTC, so add 5h (18000s).
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20-05:00"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000 + 18_000)
    }

    @Test func parseFractionalWithOffset() throws {
        // Fractional millis are preserved alongside a non-Z offset.
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20.250+08:00"))
        #expect(abs(date.timeIntervalSince1970 - (1_700_000_000.25 - 28_800)) < Self.tol)
    }

    @Test func parseCompactOffsetWithoutColon() throws {
        // The basic option set does NOT require a colon in the time zone, so +0800 parses.
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20+0800"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000 - 28_800)
    }

    // MARK: - date(from:) failure / nil branches

    @Test(arguments: [
        "",                       // empty
        "not a date",             // garbage
        "2023-11-14",             // date only, no time component (basic requires .withTime)
        "22:13:20Z",              // time only, no date
        "20231114T221320Z",       // no dash/colon separators
        "Thu, 14 Nov 2023",       // RFC-1123 style
        "1700000000",             // raw epoch number
        "2023-11-14 22:13:20Z",   // space date/time separator (not in basic option set)
    ])
    func parseInvalidStringsReturnNil(_ input: String) {
        #expect(ISO8601DateFormatter.date(from: input) == nil)
    }

    @Test func parseSlashDateSeparatorIsLenientlyAccepted() throws {
        // NOTE: On this platform ISO8601DateFormatter is lenient and accepts a
        // slash date separator even though the configured option set uses dashes.
        // Asserting the ACTUAL current behaviour (parses successfully to UTC).
        let date = try #require(ISO8601DateFormatter.date(from: "2023/11/14T22:13:20Z"))
        #expect(date.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test(arguments: [
        " 2023-11-14T22:13:20Z",   // leading whitespace tolerated
        "2023-11-14T22:13:20Z ",   // trailing whitespace tolerated
        "2023-11-14T22:13:20z",    // lowercase zulu tolerated
    ])
    func parseLenientlyAcceptedWhitespaceAndCaseVariants(_ input: String) throws {
        // Documenting platform leniency: these all still resolve to the same UTC instant.
        let date = try #require(ISO8601DateFormatter.date(from: input))
        #expect(date.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test func parseEmojiAndUnicodeReturnsNil() {
        #expect(ISO8601DateFormatter.date(from: "🗓️📅") == nil)
        #expect(ISO8601DateFormatter.date(from: "２０２３-１１-１４Ｔ２２:１３:２０Ｚ") == nil) // full-width digits
    }

    // MARK: - Round trips

    @Test(arguments: [
        1_700_000_000.5,
        0.0,
        1_692_189_296.0,
        -1000.25,
        1_000_000_000.999,
    ] as [Double])
    func roundTripStringThenDatePreservesMillisecondPrecision(_ seconds: Double) throws {
        let original = Date(timeIntervalSince1970: seconds)
        let str = ISO8601DateFormatter.string(from: original, options: Self.bothOptions)
        let parsed = try #require(ISO8601DateFormatter.date(from: str))
        // Round-tripping through millisecond rendering: compare at millisecond tolerance.
        #expect(abs(parsed.timeIntervalSince1970 - original.timeIntervalSince1970) < Self.tol)
    }

    @Test func roundTripDateThenStringStable() throws {
        // string -> date -> string should be idempotent for a canonical input.
        let canonical = "2023-11-14T22:13:20.500Z"
        let date = try #require(ISO8601DateFormatter.date(from: canonical))
        let again = ISO8601DateFormatter.string(from: date, options: Self.bothOptions)
        #expect(again == canonical)
    }

    @Test func roundTripWithoutTimeZoneOption() throws {
        // Produce without time zone, then parse back: the parser tolerates the missing 'Z'.
        let original = Self.wholeSecondDate
        let str = ISO8601DateFormatter.string(from: original, options: [])
        #expect(str == "2023-11-14T22:13:20")
        let parsed = try #require(ISO8601DateFormatter.date(from: str))
        #expect(parsed.timeIntervalSince1970 == 1_700_000_000)
    }

    // MARK: - Parser precedence

    @Test func parserPrefersFractionalFormatterRetainingMillis() throws {
        // date(from:) iterates formatters.reversed(), so the richest formatter
        // (both options) is attempted first; a fractional string keeps its millis.
        let date = try #require(ISO8601DateFormatter.date(from: "2023-11-14T22:13:20.999Z"))
        #expect(abs(date.timeIntervalSince1970 - 1_700_000_000.999) < Self.tol)
    }

    // MARK: - Consistency across many distinct dates (large, time-bounded)

    @Test func bulkRoundTripStaysConsistent() throws {
        // 100_000 distinct dates spanning ~3 years at sub-second offsets.
        let base = 1_600_000_000.0
        var maxErr = 0.0
        for i in 0 ..< 100_000 {
            let seconds = base + Double(i) + Double(i % 1000) / 1000.0
            let original = Date(timeIntervalSince1970: seconds)
            let str = ISO8601DateFormatter.string(from: original, options: Self.bothOptions)
            let parsed = try #require(ISO8601DateFormatter.date(from: str))
            maxErr = max(maxErr, abs(parsed.timeIntervalSince1970 - seconds))
        }
        #expect(maxErr < Self.tol)
    }

    // MARK: - Concurrency

    @Test func concurrentStringFormattingProducesIdenticalDeterministicResults() async {
        // The cached `formatters` are shared (nonisolated(unsafe)). Formatting from
        // many tasks concurrently must never crash and must always yield the same
        // string for the same input.
        let expected = "2023-11-14T22:13:20.500Z"
        let date = Self.referenceDate
        let results = await withTaskGroup(of: String.self) { group in
            for _ in 0 ..< 1000 {
                group.addTask { ISO8601DateFormatter.string(from: date, options: [.withTimeZone, .withFractionalSeconds]) }
            }
            var collected: [String] = []
            for await result in group { collected.append(result) }
            return collected
        }
        #expect(results.count == 1000)
        #expect(results.allSatisfy { $0 == expected })
    }

    @Test func concurrentParsingProducesIdenticalResults() async {
        let input = "2023-11-14T22:13:20.500Z"
        let results = await withTaskGroup(of: Double?.self) { group in
            for _ in 0 ..< 1000 {
                group.addTask { ISO8601DateFormatter.date(from: input)?.timeIntervalSince1970 }
            }
            var collected: [Double?] = []
            for await result in group { collected.append(result) }
            return collected
        }
        #expect(results.count == 1000)
        #expect(results.allSatisfy { $0 != nil })
        #expect(results.compactMap { $0 }.allSatisfy { abs($0 - 1_700_000_000.5) < Self.tol })
    }

    @Test func concurrentMixedReadWriteFormatAndParseNoCorruption() async {
        // Interleave formatting and parsing across all four option sets from many
        // tasks to stress the shared formatter cache. Each pairing is self-checking.
        let allOptions: [ISO8601DateFormatter.Options] = [
            [],
            [.withTimeZone],
            [.withFractionalSeconds],
            [.withTimeZone, .withFractionalSeconds],
        ]
        let oks = await withTaskGroup(of: Bool.self) { group in
            for i in 0 ..< 1000 {
                let opts = allOptions[i % allOptions.count]
                let seconds = 1_700_000_000.0 + Double(i)
                group.addTask {
                    let date = Date(timeIntervalSince1970: seconds)
                    let s = ISO8601DateFormatter.string(from: date, options: opts)
                    // Every produced string must parse back to the same whole second
                    // (these all use integer `seconds`, so no fractional loss).
                    guard let back = ISO8601DateFormatter.date(from: s) else { return false }
                    return back.timeIntervalSince1970 == seconds
                }
            }
            var count = 0
            for await ok in group where ok { count += 1 }
            return count
        }
        #expect(oks == 1000)
    }
}
