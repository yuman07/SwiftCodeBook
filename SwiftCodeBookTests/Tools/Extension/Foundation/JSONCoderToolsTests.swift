//
//  JSONCoderToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/JSONCoder+Tools.swift
//
//  Covers the two public custom Codable strategies:
//    - JSONDecoder.DateDecodingStrategy.iso8601Decode
//    - JSONEncoder.DateEncodingStrategy.iso8601Encode(options:)
//
//  Both strategies are `.custom` closures, so they are only meaningfully
//  observable end-to-end through a real JSONEncoder / JSONDecoder round-trip.
//  The tests therefore drive actual encode / decode of Date-bearing JSON.
//
//  These strategies delegate to the project's ISO8601DateFormatter extension
//  (ISO8601DateFormatter+Tools.swift), whose formatter pool uses default
//  ISO8601DateFormatter instances (whose `timeZone` is GMT). All emitted /
//  parsed wall-clock strings are therefore in GMT/UTC; the tests pin reference
//  dates by absolute timeIntervalSince1970 so they are independent of the
//  machine timezone.
//
//  Encoder option -> formatter index mapping (verified against the source):
//    optionals == [.withTimeZone, .withFractionalSeconds]
//      []                              -> index 0 (no zone, no fraction)
//      [.withTimeZone]                 -> index 1 (Z, no fraction)
//      [.withFractionalSeconds]        -> index 2 (no zone, .SSS)
//      [.withTimeZone,.withFractional] -> index 3 (Z + .SSS)  (default)
//    Only the two `optionals` flags affect index selection; any other flag is
//    ignored when choosing the formatter.
//  Decoder tries the formatters in reverse (index 3 -> 0), returning the first
//  that parses; all formatters share the GMT timeZone, so a string lacking a
//  zone designator is read as GMT wall-clock.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct JSONCoderToolsTests {

    // MARK: - Fixtures

    // A Codable box holding a single Date so we can exercise the strategies via
    // the encoder/decoder container the closures actually receive.
    // Nested + private so it never collides with same-named helpers elsewhere
    // in the single-module test target.
    private struct Box: Codable, Equatable {
        var date: Date
    }

    // 2023-08-16T12:34:56.500Z == 1692189296.5 seconds since 1970.
    private static let refSeconds: TimeInterval = 1_692_189_296.5
    private static let refDate = Date(timeIntervalSince1970: refSeconds)
    // Same instant truncated to whole seconds.
    private static let refDateWhole = Date(timeIntervalSince1970: 1_692_189_296)

    private func encoder(_ enc: JSONEncoder.DateEncodingStrategy) -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = enc
        return e
    }

    private func decoder(_ dec: JSONDecoder.DateDecodingStrategy = .iso8601Decode) -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = dec
        return d
    }

    // Encode a single top-level Date and return the produced JSON string
    // (a bare JSON string literal, surrounding quotes stripped).
    private func encodedString(_ date: Date, _ strategy: JSONEncoder.DateEncodingStrategy) throws -> String {
        let data = try encoder(strategy).encode(date)
        let raw = try #require(String(data: data, encoding: .utf8))
        #expect(raw.hasPrefix("\""))
        #expect(raw.hasSuffix("\""))
        #expect(raw.count >= 2)
        return String(raw.dropFirst().dropLast())
    }

    private func jsonString(_ value: String) -> Data {
        // Produces a top-level JSON string: "value"
        Data("\"\(value)\"".utf8)
    }

    // MARK: - Encoding: default options ([.withTimeZone, .withFractionalSeconds])

    @Test func encodeDefaultOptionsProducesFractionalUTCString() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode())
        #expect(s == "2023-08-16T12:34:56.500Z")
    }

    @Test func encodeDefaultOptionsWholeSecondStillHasFractionalAndZ() throws {
        let s = try encodedString(Self.refDateWhole, .iso8601Encode())
        #expect(s == "2023-08-16T12:34:56.000Z")
    }

    @Test func encodeEpochDefaultOptions() throws {
        let s = try encodedString(Date(timeIntervalSince1970: 0), .iso8601Encode())
        #expect(s == "1970-01-01T00:00:00.000Z")
    }

    @Test func encodeNegativeEpochDefaultOptions() throws {
        // One second before the epoch: must roll the wall clock back across midnight.
        let s = try encodedString(Date(timeIntervalSince1970: -1), .iso8601Encode())
        #expect(s == "1969-12-31T23:59:59.000Z")
    }

    // MARK: - Encoding: explicit option combinations

    @Test func encodeNoOptionsOmitsZoneAndFraction() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: []))
        // No timezone designator, no fractional seconds; GMT wall clock.
        #expect(s == "2023-08-16T12:34:56")
    }

    @Test func encodeTimeZoneOnlyAddsZNoFraction() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withTimeZone]))
        #expect(s == "2023-08-16T12:34:56Z")
    }

    @Test func encodeFractionalOnlyAddsFractionNoZone() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withFractionalSeconds]))
        #expect(s == "2023-08-16T12:34:56.500")
    }

    @Test func encodeBothOptionsExplicitlyEqualsDefault() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withTimeZone, .withFractionalSeconds]))
        #expect(s == "2023-08-16T12:34:56.500Z")
    }

    // Unknown / extra options that are not in the `optionals` set map to the
    // same index as their base combination (the extension only inspects
    // .withTimeZone and .withFractionalSeconds when computing the formatter
    // index). Adding an unrelated flag must not change the chosen formatter.
    @Test func encodeUnrelatedOptionDoesNotChangeFormatterSelection() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withTimeZone, .withFractionalSeconds, .withColonSeparatorInTime]))
        #expect(s == "2023-08-16T12:34:56.500Z")
    }

    // The same unrelated-flag invariance must hold for the no-options case:
    // an extra non-`optionals` flag still selects formatter index 0.
    @Test func encodeUnrelatedOptionWithEmptyBaseStillSelectsIndexZero() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withColonSeparatorInTimeZone]))
        #expect(s == "2023-08-16T12:34:56")
    }

    // Parameterized matrix of the four canonical option combinations -> exact output.
    @Test(arguments: [
        (ISO8601DateFormatter.Options([]), "2023-08-16T12:34:56"),
        (ISO8601DateFormatter.Options([.withTimeZone]), "2023-08-16T12:34:56Z"),
        (ISO8601DateFormatter.Options([.withFractionalSeconds]), "2023-08-16T12:34:56.500"),
        (ISO8601DateFormatter.Options([.withTimeZone, .withFractionalSeconds]), "2023-08-16T12:34:56.500Z"),
    ])
    func encodeOptionMatrix(_ options: ISO8601DateFormatter.Options, _ expected: String) throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: options))
        #expect(s == expected)
    }

    // MARK: - Encoding: nested in a struct

    @Test func encodeDateNestedInStruct() throws {
        let data = try encoder(.iso8601Encode()).encode(Box(date: Self.refDate))
        let raw = try #require(String(data: data, encoding: .utf8))
        #expect(raw == #"{"date":"2023-08-16T12:34:56.500Z"}"#)
    }

    // MARK: - Decoding: happy paths

    @Test func decodeFractionalUTCString() throws {
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T12:34:56.500Z"))
        #expect(date == Self.refDate)
    }

    @Test func decodeWholeSecondWithZ() throws {
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T12:34:56Z"))
        #expect(date == Self.refDateWhole)
    }

    @Test func decodeWithoutTimeZoneIsInterpretedAsGMT() throws {
        // No zone designator -> the GMT formatter pool reads it as GMT wall clock.
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T12:34:56"))
        #expect(date == Self.refDateWhole)
    }

    @Test func decodeFractionalWithoutTimeZone() throws {
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T12:34:56.500"))
        #expect(date == Self.refDate)
    }

    @Test func decodeNumericOffsetNormalizesToUTCInstant() throws {
        // 20:34:56+08:00 is the same absolute instant as 12:34:56Z.
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T20:34:56+08:00"))
        #expect(date == Self.refDateWhole)
    }

    @Test func decodeNumericOffsetWithoutColonNormalizesToUTCInstant() throws {
        // The pooled formatters parse +0800 (no colon in zone) as the same instant.
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T20:34:56+0800"))
        #expect(date == Self.refDateWhole)
    }

    @Test func decodeFractionalWithNumericOffsetPreservesSubSecond() throws {
        // Sub-second precision survives a non-Z numeric offset.
        let date = try decoder().decode(Date.self, from: jsonString("2023-08-16T20:34:56.500+08:00"))
        #expect(date == Self.refDate)
    }

    @Test func decodeNestedInStruct() throws {
        let data = Data(#"{"date":"2023-08-16T12:34:56.500Z"}"#.utf8)
        let box = try decoder().decode(Box.self, from: data)
        #expect(box.date == Self.refDate)
    }

    @Test func decodeEpoch() throws {
        let date = try decoder().decode(Date.self, from: jsonString("1970-01-01T00:00:00.000Z"))
        #expect(date == Date(timeIntervalSince1970: 0))
    }

    // Table-driven valid inputs that must all parse to the same whole-second instant.
    @Test(arguments: [
        "2023-08-16T12:34:56Z",
        "2023-08-16T12:34:56",
        "2023-08-16T20:34:56+08:00",
        "2023-08-16T04:34:56-08:00",
        "2023-08-16T20:34:56+0800",
    ])
    func decodeEquivalentRepresentations(_ input: String) throws {
        let date = try decoder().decode(Date.self, from: jsonString(input))
        #expect(date == Self.refDateWhole)
    }

    // MARK: - Decoding: failure / error branch

    @Test func decodeInvalidStringThrowsDataCorrupted() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: jsonString("not-a-date"))
        }
    }

    @Test func decodeEmptyStringThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: jsonString(""))
        }
    }

    @Test func decodeDateOnlyMissingTimeThrows() {
        // The formatter pool always requires .withTime, so a date-only value fails.
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: jsonString("2023-08-16"))
        }
    }

    // A space separator (instead of "T") between date and time is rejected by
    // the strict ISO8601 pool.
    @Test func decodeSpaceSeparatedDateTimeThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: jsonString("2023-08-16 12:34:56Z"))
        }
    }

    // Missing the seconds component is not a valid full ISO8601 time here.
    @Test func decodeMissingSecondsThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: jsonString("2023-08-16T12:34Z"))
        }
    }

    // The error specifically is .dataCorrupted (as thrown by dataCorruptedError),
    // and the debug description echoes the offending string.
    @Test func decodeInvalidStringIsDataCorruptedWithEchoedValue() throws {
        let error = try #require(performThrowing {
            _ = try decoder().decode(Date.self, from: jsonString("garbage-value"))
        })
        let decodingError = try #require(error as? DecodingError)
        guard case let .dataCorrupted(context) = decodingError else {
            Issue.record("Expected DecodingError.dataCorrupted, got \(decodingError)")
            return
        }
        #expect(context.debugDescription.contains("garbage-value"))
    }

    // A decode failure nested inside a keyed container still surfaces as a
    // DecodingError (the strategy's throw propagates out of the container).
    @Test func decodeFailureInsideNestedStructPropagates() {
        let data = Data(#"{"date":"totally-bogus"}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Box.self, from: data)
        }
    }

    // A non-string JSON value (number) cannot be decoded as String first, so the
    // singleValueContainer.decode(String.self) inside the strategy throws.
    @Test func decodeNonStringJSONValueThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: Data("1234567890".utf8))
        }
    }

    @Test func decodeBoolJSONValueThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: Data("true".utf8))
        }
    }

    @Test func decodeNullJSONValueThrows() {
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode(Date.self, from: Data("null".utf8))
        }
    }

    // MARK: - Round trips

    @Test func roundTripDefaultOptionsPreservesFractionalSecond() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode())
        let back = try decoder().decode(Date.self, from: jsonString(s))
        #expect(back == Self.refDate)
    }

    @Test func roundTripFractionalOnlyPreservesFractionalSecond() throws {
        // Even without a zone designator, the fractional component is preserved
        // and the no-zone string is read back as GMT -> identical instant.
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withFractionalSeconds]))
        #expect(s == "2023-08-16T12:34:56.500")
        let back = try decoder().decode(Date.self, from: jsonString(s))
        #expect(back == Self.refDate)
    }

    @Test func roundTripNoOptionsLosesSubSecond() throws {
        // Without fractional option the sub-second part is dropped on encode,
        // so the decoded value collapses to the whole-second instant.
        let s = try encodedString(Self.refDate, .iso8601Encode(options: []))
        let back = try decoder().decode(Date.self, from: jsonString(s))
        #expect(back == Self.refDateWhole)
    }

    @Test func roundTripTimeZoneOnlyLosesSubSecond() throws {
        let s = try encodedString(Self.refDate, .iso8601Encode(options: [.withTimeZone]))
        let back = try decoder().decode(Date.self, from: jsonString(s))
        #expect(back == Self.refDateWhole)
    }

    @Test func roundTripNestedStructDefaultOptions() throws {
        let original = Box(date: Self.refDate)
        let data = try encoder(.iso8601Encode()).encode(original)
        let restored = try decoder().decode(Box.self, from: data)
        #expect(restored == original)
    }

    // Table-driven round-trip across a spread of instants using default options
    // (fractional seconds preserved). All values use a .0 fractional component
    // so encode produces ".000" and decode restores the exact Date.
    @Test(arguments: [
        TimeInterval(0),
        TimeInterval(1),
        TimeInterval(-1),                  // before the epoch
        TimeInterval(1_692_189_296),       // 2023-08-16
        TimeInterval(978_307_200),         // 2001-01-01 (reference date origin)
        TimeInterval(4_102_444_800),       // 2100-01-01
    ])
    func roundTripWholeSecondInstants(_ seconds: TimeInterval) throws {
        let date = Date(timeIntervalSince1970: seconds)
        let s = try encodedString(date, .iso8601Encode())
        #expect(s.hasSuffix(".000Z"))
        let back = try decoder().decode(Date.self, from: jsonString(s))
        #expect(back == date)
    }

    // MARK: - Arrays / large data

    @Test func encodeEmptyArrayOfDates() throws {
        let data = try encoder(.iso8601Encode()).encode([Date]())
        let raw = try #require(String(data: data, encoding: .utf8))
        #expect(raw == "[]")
    }

    @Test func decodeEmptyArrayOfDates() throws {
        let dates = try decoder().decode([Date].self, from: Data("[]".utf8))
        #expect(dates.isEmpty)
    }

    @Test func decodeArrayOfDates() throws {
        let json = Data("""
        ["2023-08-16T12:34:56.500Z","1970-01-01T00:00:00.000Z","2023-08-16T12:34:56Z"]
        """.utf8)
        let dates = try decoder().decode([Date].self, from: json)
        #expect(dates.count == 3)
        #expect(dates[0] == Self.refDate)
        #expect(dates[1] == Date(timeIntervalSince1970: 0))
        #expect(dates[2] == Self.refDateWhole)
    }

    // A single malformed element inside an otherwise-valid array still aborts decoding.
    @Test func decodeArrayWithOneInvalidElementThrows() {
        let json = Data(#"["2023-08-16T12:34:56.500Z","nope"]"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try decoder().decode([Date].self, from: json)
        }
    }

    @Test func encodeAndDecodeLargeArrayRoundTrips() throws {
        let count = 100_000
        // Build distinct whole-second instants so default-option round-trips are exact.
        let base = 1_600_000_000
        let dates = (0..<count).map { Date(timeIntervalSince1970: TimeInterval(base + $0)) }
        let data = try encoder(.iso8601Encode()).encode(dates)
        let restored = try decoder().decode([Date].self, from: data)
        #expect(restored.count == count)
        #expect(restored == dates)
    }

    // MARK: - Concurrency

    // The strategies funnel into the shared static ISO8601DateFormatter pool
    // (nonisolated(unsafe)). Hammer encode+decode from many concurrent tasks and
    // assert every round-trip is correct with no lost/garbled results. The task
    // closures capture only Sendable values (an Int index) and construct fresh
    // JSONEncoder/JSONDecoder instances locally, so this is deterministic and
    // free of data races aside from the intentionally-shared formatter pool.
    @Test func concurrentEncodeDecodeIsConsistent() async {
        let iterations = 1000
        let mismatches = await withTaskGroup(of: Int?.self, returning: [Int].self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let date = Date(timeIntervalSince1970: TimeInterval(1_600_000_000 + i))
                    let enc = JSONEncoder()
                    enc.dateEncodingStrategy = .iso8601Encode()
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601Decode
                    guard let data = try? enc.encode(date),
                          let back = try? dec.decode(Date.self, from: data),
                          back == date else {
                        return i // report the failing iteration index
                    }
                    return nil
                }
            }
            var failed: [Int] = []
            for await result in group {
                if let i = result { failed.append(i) }
            }
            return failed
        }
        #expect(mismatches.isEmpty, "Round-trip failed for iterations: \(mismatches.sorted())")
    }

    @Test func concurrentDecodeOfSameValue() async {
        let iterations = 500
        let expected = Self.refDate
        let goodCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    let dec = JSONDecoder()
                    dec.dateDecodingStrategy = .iso8601Decode
                    let decoded = try? dec.decode(Date.self, from: Data("\"2023-08-16T12:34:56.500Z\"".utf8))
                    return decoded == expected
                }
            }
            var good = 0
            for await ok in group where ok {
                good += 1
            }
            return good
        }
        #expect(goodCount == iterations)
    }

    // MARK: - Helpers

    // Captures any error thrown by `body`, returning it (or nil if none). Used to
    // inspect a thrown error's concrete case without leaking #expect semantics.
    private func performThrowing(_ body: () throws -> Void) -> Error? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }
}
