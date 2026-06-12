//
//  DateFormatterToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/DateFormatter+Tools.swift
//  Covers the public `DateFormatter.Format` value type (init / stored props /
//  Hashable / Sendable) and the two static convenience APIs:
//    - DateFormatter.string(from:format:)
//    - DateFormatter.date(from:format:)
//  The internal cache (private `dateFormatterMap` / `dateFormatter(with:)`,
//  backed by `MemoryCache` over `NSCache`) is exercised indirectly via repeated
//  and concurrent calls — verifying correct results, isolation between distinct
//  formats, and thread-safety. Note `NSCache` may evict at its own discretion,
//  but the source re-creates a formatter on any miss, so results stay correct
//  regardless of eviction.
//
//  All tests pin an explicit Locale / TimeZone (never the machine default) so
//  formatting/parsing is deterministic regardless of the simulator settings.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct DateFormatterToolsTests {

    // Stable building blocks reused across tests. POSIX locale gives a fixed,
    // locale-independent rendering for fixed-format strings.
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let utc = TimeZone(identifier: "UTC")!

    private static func utcFormat(_ pattern: String) -> DateFormatter.Format {
        .init(dateFormat: pattern, locale: posix, timeZone: utc)
    }

    // A reference Date: 2023-08-16 12:34:56 UTC (a Wednesday).
    // 2023-08-16T12:34:56Z == 1692189296 seconds since 1970.
    private static let referenceDate = Date(timeIntervalSince1970: 1_692_189_296)

    // MARK: - Format.init defaults

    @Test func formatInitStoresProvidedValues() {
        let locale = Locale(identifier: "fr_FR")
        let tz = TimeZone(identifier: "Asia/Shanghai")!
        let format = DateFormatter.Format(dateFormat: "yyyy-MM-dd", locale: locale, timeZone: tz)
        #expect(format.dateFormat == "yyyy-MM-dd")
        #expect(format.locale == locale)
        #expect(format.timeZone == tz)
    }

    @Test func formatInitUsesCurrentDefaultsWhenOmitted() {
        let format = DateFormatter.Format(dateFormat: "HH:mm")
        #expect(format.dateFormat == "HH:mm")
        #expect(format.locale == .current)
        #expect(format.timeZone == .current)
    }

    @Test func formatInitDefaultLocaleOnly() {
        let tz = TimeZone(identifier: "America/New_York")!
        let format = DateFormatter.Format(dateFormat: "yyyy", timeZone: tz)
        #expect(format.locale == .current)
        #expect(format.timeZone == tz)
    }

    @Test func formatInitDefaultTimeZoneOnly() {
        let locale = Locale(identifier: "ja_JP")
        let format = DateFormatter.Format(dateFormat: "yyyy", locale: locale)
        #expect(format.locale == locale)
        #expect(format.timeZone == .current)
    }

    @Test func formatAcceptsEmptyDateFormat() {
        // Empty pattern is a legal (if useless) value; init must not choke.
        let format = Self.utcFormat("")
        #expect(format.dateFormat.isEmpty)
    }

    @Test func formatAcceptsUnicodeDateFormat() {
        // Unicode in the pattern (CJK literals) must be stored verbatim.
        let format = Self.utcFormat("yyyy'年'MM'月'dd'日'")
        #expect(format.dateFormat == "yyyy'年'MM'月'dd'日'")
    }

    // MARK: - Format Hashable / Equatable

    @Test func formatEqualityWhenAllFieldsMatch() {
        let a = Self.utcFormat("yyyy-MM-dd")
        let b = Self.utcFormat("yyyy-MM-dd")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func formatInequalityOnDateFormat() {
        let a = Self.utcFormat("yyyy-MM-dd")
        let b = Self.utcFormat("yyyy/MM/dd")
        #expect(a != b)
    }

    @Test func formatInequalityOnLocale() {
        let a = DateFormatter.Format(dateFormat: "yyyy", locale: Locale(identifier: "en_US"), timeZone: Self.utc)
        let b = DateFormatter.Format(dateFormat: "yyyy", locale: Locale(identifier: "fr_FR"), timeZone: Self.utc)
        #expect(a != b)
    }

    @Test func formatInequalityOnTimeZone() {
        let a = DateFormatter.Format(dateFormat: "yyyy", locale: Self.posix, timeZone: TimeZone(identifier: "UTC")!)
        let b = DateFormatter.Format(dateFormat: "yyyy", locale: Self.posix, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        #expect(a != b)
    }

    @Test func formatUsableAsDictionaryAndSetKey() {
        // Confirms Hashable conformance is well-behaved for collection keys.
        let a = Self.utcFormat("yyyy-MM-dd")
        let aDup = Self.utcFormat("yyyy-MM-dd")
        let c = Self.utcFormat("HH:mm")

        var dict: [DateFormatter.Format: Int] = [:]
        dict[a] = 1
        dict[aDup] = 2 // overwrites a, same key
        dict[c] = 3
        #expect(dict.count == 2)
        #expect(dict[a] == 2)
        #expect(dict[c] == 3)

        let set: Set<DateFormatter.Format> = [a, aDup, c]
        #expect(set.count == 2)
        #expect(set.contains(Self.utcFormat("yyyy-MM-dd")))
        #expect(!set.contains(Self.utcFormat("yyyy")))
    }

    // MARK: - string(from:format:) happy path

    @Test func stringFromDateFullPattern() {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let result = DateFormatter.string(from: Self.referenceDate, format: format)
        #expect(result == "2023-08-16 12:34:56")
    }

    @Test func stringFromDateRespectsTimeZone() {
        // Same instant rendered in two different zones must differ accordingly.
        let utcFormat = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let tokyo = DateFormatter.Format(
            dateFormat: "yyyy-MM-dd HH:mm:ss",
            locale: Self.posix,
            timeZone: TimeZone(identifier: "Asia/Tokyo")! // UTC+9
        )
        let utcString = DateFormatter.string(from: Self.referenceDate, format: utcFormat)
        let tokyoString = DateFormatter.string(from: Self.referenceDate, format: tokyo)
        #expect(utcString == "2023-08-16 12:34:56")
        #expect(tokyoString == "2023-08-16 21:34:56")
    }

    @Test func stringFromDateRespectsLocale() {
        // Month name should localize. August in French is "août".
        let french = DateFormatter.Format(
            dateFormat: "MMMM",
            locale: Locale(identifier: "fr_FR"),
            timeZone: Self.utc
        )
        let english = DateFormatter.Format(
            dateFormat: "MMMM",
            locale: Locale(identifier: "en_US"),
            timeZone: Self.utc
        )
        #expect(DateFormatter.string(from: Self.referenceDate, format: french) == "août")
        #expect(DateFormatter.string(from: Self.referenceDate, format: english) == "August")
    }

    @Test func stringFromDateRespectsLocaleForWeekday() {
        // The reference instant is a Wednesday. Weekday name localizes too.
        let english = DateFormatter.Format(dateFormat: "EEEE", locale: Locale(identifier: "en_US"), timeZone: Self.utc)
        let french = DateFormatter.Format(dateFormat: "EEEE", locale: Locale(identifier: "fr_FR"), timeZone: Self.utc)
        #expect(DateFormatter.string(from: Self.referenceDate, format: english) == "Wednesday")
        #expect(DateFormatter.string(from: Self.referenceDate, format: french) == "mercredi")
    }

    @Test func stringFromDate12HourClock() {
        // 12:34:56 in a 12-hour clock with AM/PM marker (POSIX => PM).
        let format = Self.utcFormat("hh:mm a")
        #expect(DateFormatter.string(from: Self.referenceDate, format: format) == "12:34 PM")
    }

    @Test(arguments: [
        ("yyyy", "2023"),
        ("MM", "08"),
        ("dd", "16"),
        ("HH", "12"),
        ("mm", "34"),
        ("ss", "56"),
        ("yyyy-MM-dd", "2023-08-16"),
        ("HH:mm:ss", "12:34:56"),
        ("yyyy-MM", "2023-08"),
        ("MM-dd", "08-16"),
        ("HH:mm", "12:34"),
        ("mm:ss", "34:56"),
    ])
    func stringFromDateVariousPatterns(pattern: String, expected: String) {
        let format = Self.utcFormat(pattern)
        #expect(DateFormatter.string(from: Self.referenceDate, format: format) == expected)
    }

    @Test func stringFromEpochZero() {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let result = DateFormatter.string(from: Date(timeIntervalSince1970: 0), format: format)
        #expect(result == "1970-01-01 00:00:00")
    }

    @Test func stringFromFractionalSeconds() {
        // Sub-second precision in the source Date must render with SSS.
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss.SSS")
        let date = Date(timeIntervalSince1970: 1_692_189_296.5)
        #expect(DateFormatter.string(from: date, format: format) == "2023-08-16 12:34:56.500")
    }

    @Test func stringWithEmptyPatternIsEmpty() {
        // An empty dateFormat yields an empty string.
        let format = Self.utcFormat("")
        #expect(DateFormatter.string(from: Self.referenceDate, format: format) == "")
    }

    @Test func stringWithLiteralTextInPattern() {
        // Quoted literals must pass through verbatim.
        let format = Self.utcFormat("'Year:' yyyy")
        #expect(DateFormatter.string(from: Self.referenceDate, format: format) == "Year: 2023")
    }

    @Test func stringWithUnicodeLiteralInPattern() {
        // Quoted non-ASCII literals must round-trip through the formatter intact.
        let format = Self.utcFormat("'年份：'yyyy'年'")
        #expect(DateFormatter.string(from: Self.referenceDate, format: format) == "年份：2023年")
    }

    // MARK: - string(from:format:) boundaries / extremes

    @Test func stringFromDistantPast() {
        // Should not crash on an extreme Date; just assert it is non-empty.
        // Exact value depends on the proleptic Gregorian calendar / ICU, so we
        // only assert non-emptiness to stay robust across OS boundaries.
        let format = Self.utcFormat("yyyy-MM-dd")
        let result = DateFormatter.string(from: .distantPast, format: format)
        #expect(!result.isEmpty)
    }

    @Test func stringFromDistantFuture() {
        let format = Self.utcFormat("yyyy-MM-dd")
        let result = DateFormatter.string(from: .distantFuture, format: format)
        #expect(!result.isEmpty)
    }

    // MARK: - date(from:format:) happy path

    @Test func dateFromStringFullPattern() throws {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let parsed = try #require(DateFormatter.date(from: "2023-08-16 12:34:56", format: format))
        #expect(parsed == Self.referenceDate)
    }

    @Test func dateFromStringEpochZero() throws {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let parsed = try #require(DateFormatter.date(from: "1970-01-01 00:00:00", format: format))
        #expect(parsed == Date(timeIntervalSince1970: 0))
    }

    @Test func dateFromStringRespectsTimeZone() throws {
        // The same wall-clock string parses to different instants per zone.
        let utcFormat = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let tokyo = DateFormatter.Format(
            dateFormat: "yyyy-MM-dd HH:mm:ss",
            locale: Self.posix,
            timeZone: TimeZone(identifier: "Asia/Tokyo")! // UTC+9
        )
        let utcDate = try #require(DateFormatter.date(from: "2023-08-16 12:34:56", format: utcFormat))
        let tokyoDate = try #require(DateFormatter.date(from: "2023-08-16 12:34:56", format: tokyo))
        // Tokyo wall-clock is 9 hours ahead, so the instant is 9h earlier in UTC.
        #expect(utcDate.timeIntervalSince(tokyoDate) == 9 * 3600)
    }

    @Test func dateFromStringRespectsNegativeOffsetTimeZone() throws {
        // New York in August is UTC-4 (EDT, DST in effect). Same wall-clock
        // string therefore parses 4h later (in UTC) than the UTC interpretation.
        let utcFormat = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let ny = DateFormatter.Format(
            dateFormat: "yyyy-MM-dd HH:mm:ss",
            locale: Self.posix,
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        let utcDate = try #require(DateFormatter.date(from: "2023-08-16 12:34:56", format: utcFormat))
        let nyDate = try #require(DateFormatter.date(from: "2023-08-16 12:34:56", format: ny))
        #expect(nyDate.timeIntervalSince(utcDate) == 4 * 3600)
    }

    // MARK: - date(from:format:) failure branch

    @Test(arguments: [
        "not a date",
        "",
        "2023-13-99 99:99:99", // out-of-range components for a fixed-format parse
        "16-08-2023 12:34:56", // wrong field order
        "   ",                 // whitespace only
        "2023-08-16",          // missing the time portion
    ])
    func dateFromMalformedStringReturnsNil(bad: String) {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        #expect(DateFormatter.date(from: bad, format: format) == nil)
    }

    @Test func dateFormatterTreatsDashAndSlashSeparatorsInterchangeably() throws {
        // Documented quirk: DateFormatter treats "-" / "/" / "." as equivalent
        // field separators, so "2023/08/16 ..." parses against a "yyyy-MM-dd"
        // pattern. Assert the ACTUAL current behavior.
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let parsed = try #require(DateFormatter.date(from: "2023/08/16 12:34:56", format: format))
        #expect(parsed == Self.referenceDate)
    }

    @Test func dateFromStringWithTrailingGarbageReturnsNil() {
        // DateFormatter.date(from:) requires the whole string to match.
        let format = Self.utcFormat("yyyy-MM-dd")
        #expect(DateFormatter.date(from: "2023-08-16 trailing", format: format) == nil)
    }

    @Test func dateFromMismatchedPatternReturnsNil() {
        // String is a valid date but the pattern expects a time-only format.
        let format = Self.utcFormat("HH:mm:ss")
        #expect(DateFormatter.date(from: "2023-08-16", format: format) == nil)
    }

    // MARK: - Round trips

    @Test(arguments: [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy/MM/dd'T'HH:mm:ss",
        "dd MMM yyyy HH:mm:ss",
    ])
    func roundTripDateStringDate(pattern: String) throws {
        let format = Self.utcFormat(pattern)
        let str = DateFormatter.string(from: Self.referenceDate, format: format)
        let parsed = try #require(DateFormatter.date(from: str, format: format))
        // Pattern carries full second precision, so it must round-trip exactly.
        #expect(parsed == Self.referenceDate)
    }

    @Test func roundTripStringDateString() throws {
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let original = "2001-12-31 23:59:58"
        let date = try #require(DateFormatter.date(from: original, format: format))
        let back = DateFormatter.string(from: date, format: format)
        #expect(back == original)
    }

    @Test func roundTripWithFractionalSeconds() throws {
        // Round-trip a sub-second instant; with SSS the fractional part survives.
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss.SSS")
        let date = Date(timeIntervalSince1970: 1_692_189_296.5)
        let str = DateFormatter.string(from: date, format: format)
        let parsed = try #require(DateFormatter.date(from: str, format: format))
        // Allow a tiny tolerance for millisecond truncation in the round-trip.
        #expect(abs(parsed.timeIntervalSince(date)) < 0.0005)
    }

    // MARK: - Caching behavior (indirect, via repeated calls)

    @Test func repeatedCallsSameFormatAreConsistent() {
        // First call populates the cache; subsequent calls must return the
        // same value (the cached formatter must be configured identically).
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let first = DateFormatter.string(from: Self.referenceDate, format: format)
        for _ in 0..<200 {
            #expect(DateFormatter.string(from: Self.referenceDate, format: format) == first)
        }
        #expect(first == "2023-08-16 12:34:56")
    }

    @Test func distinctFormatsDoNotInterfere() {
        // Two formats sharing the same instant but differing patterns must
        // each keep their own cached formatter and not bleed configuration.
        let dateOnly = Self.utcFormat("yyyy-MM-dd")
        let timeOnly = Self.utcFormat("HH:mm:ss")
        // Interleave to surface any shared-state bug in the cache.
        for _ in 0..<100 {
            #expect(DateFormatter.string(from: Self.referenceDate, format: dateOnly) == "2023-08-16")
            #expect(DateFormatter.string(from: Self.referenceDate, format: timeOnly) == "12:34:56")
        }
    }

    @Test func cacheDoesNotConfusePatternsThatDifferOnlyByLocale() {
        // Same pattern + same zone but differing locales are distinct keys.
        // The cache must not return the wrong locale's formatter.
        let en = DateFormatter.Format(dateFormat: "MMMM", locale: Locale(identifier: "en_US"), timeZone: Self.utc)
        let fr = DateFormatter.Format(dateFormat: "MMMM", locale: Locale(identifier: "fr_FR"), timeZone: Self.utc)
        for _ in 0..<50 {
            #expect(DateFormatter.string(from: Self.referenceDate, format: en) == "August")
            #expect(DateFormatter.string(from: Self.referenceDate, format: fr) == "août")
        }
    }

    // MARK: - Concurrency (cache is guarded by OSAllocatedUnfairLock)

    @Test func concurrentStringCallsSameFormat() async {
        // Hammer a single format from many tasks. The lock-guarded cache must
        // produce a correct, identical result every time with no crash.
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let expected = "2023-08-16 12:34:56"
        let date = Self.referenceDate

        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<1000 {
                group.addTask {
                    DateFormatter.string(from: date, format: format) == expected
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }

    @Test func concurrentStringCallsManyDistinctFormats() async {
        // Many distinct cache keys created concurrently. Each task knows its
        // own expected output, so a corrupted/shared formatter would fail.
        let date = Self.referenceDate
        let patterns = ["yyyy", "MM", "dd", "HH", "mm", "ss", "yyyy-MM", "MM-dd", "HH:mm", "mm:ss"]
        let expected: [String: String] = [
            "yyyy": "2023", "MM": "08", "dd": "16", "HH": "12", "mm": "34",
            "ss": "56", "yyyy-MM": "2023-08", "MM-dd": "08-16",
            "HH:mm": "12:34", "mm:ss": "34:56",
        ]

        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1000 {
                let pattern = patterns[i % patterns.count]
                let want = expected[pattern]!
                group.addTask {
                    let format = Self.utcFormat(pattern)
                    return DateFormatter.string(from: date, format: format) == want
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }

    @Test func concurrentParseAndFormatMixed() async {
        // Mix readers (date(from:)) and writers (string(from:)) across tasks to
        // stress the lock under contention on overlapping keys.
        let format = Self.utcFormat("yyyy-MM-dd HH:mm:ss")
        let date = Self.referenceDate
        let str = "2023-08-16 12:34:56"

        let results: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1000 {
                if i.isMultiple(of: 2) {
                    group.addTask {
                        DateFormatter.string(from: date, format: format) == str
                    }
                } else {
                    group.addTask {
                        DateFormatter.date(from: str, format: format) == date
                    }
                }
            }
            var collected: [Bool] = []
            for await ok in group {
                collected.append(ok)
            }
            return collected
        }
        #expect(results.count == 1000)
        #expect(results.allSatisfy { $0 })
    }

    // MARK: - Large / many distinct formats (stress the cache, time-bounded)

    @Test func manyUniqueFormatsDoNotCorrupt() {
        // Build a large number of distinct keys; verify each still produces its
        // own correct output. Exercises cache growth / NSCache eviction paths
        // (eviction is fine: a miss re-creates a correctly configured formatter).
        let date = Self.referenceDate
        for year in 0..<2000 {
            // Each unique literal makes a unique cache key.
            let format = Self.utcFormat("'#\(year)' yyyy")
            #expect(DateFormatter.string(from: date, format: format) == "#\(year) 2023")
        }
    }

    // MARK: - Sendable conformance (compile-time check via crossing isolation)

    @Test func formatIsSendableAcrossTasks() async {
        let format = Self.utcFormat("yyyy")
        let captured = await Task.detached {
            // If Format were not Sendable, capturing it here would not compile
            // under strict concurrency.
            DateFormatter.string(from: Self.referenceDate, format: format)
        }.value
        #expect(captured == "2023")
    }
}
