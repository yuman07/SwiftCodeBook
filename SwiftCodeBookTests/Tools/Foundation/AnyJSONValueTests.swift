//
//  AnyJSONValueTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Foundation/AnyJSONValue.swift
//
//  AnyJSONValue is a @frozen public enum that models an arbitrary JSON value
//  (null / string / int / double / bool / array / dictionary). It is
//  Codable, Hashable and Sendable, with convenience accessors
//  (isNull / stringValue / intValue / doubleValue / boolValue / arrayValue /
//  dictionaryValue).
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct AnyJSONValueTests {

    // MARK: - Helpers

    /// Encode a value to JSON Data using a deterministic encoder.
    private func encode(_ value: AnyJSONValue, sortKeys: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        if sortKeys {
            encoder.outputFormatting = [.sortedKeys]
        }
        return try encoder.encode(value)
    }

    /// Decode a JSON literal (top-level fragments allowed) into AnyJSONValue.
    private func decode(_ json: String) throws -> AnyJSONValue {
        let decoder = JSONDecoder()
        // Allow scalar / fragment top-levels like `42`, `"x"`, `true`, `null`.
        decoder.allowsJSON5 = false
        return try decoder.decode(AnyJSONValue.self, from: Data(json.utf8))
    }

    private func decodeFragment(_ json: String) throws -> AnyJSONValue {
        let decoder = JSONDecoder()
        return try decoder.decode(AnyJSONValue.self, from: Data(json.utf8))
    }

    /// Discriminator used to assert *which* enum case a value landed in,
    /// independent of the convenience accessors under test.
    private func caseTag(_ value: AnyJSONValue) -> String {
        switch value {
        case .null: return "null"
        case .string: return "string"
        case .int: return "int"
        case .double: return "double"
        case .bool: return "bool"
        case .array: return "array"
        case .dictionary: return "dictionary"
        }
    }

    // MARK: - Accessor: isNull

    @Test func isNullTrueOnlyForNull() {
        #expect(AnyJSONValue.null.isNull == true)
    }

    @Test(arguments: [
        AnyJSONValue.string("x"),
        .string(""),
        .int(0),
        .double(0),
        .bool(false),
        .array([]),
        .dictionary([:]),
    ])
    func isNullFalseForNonNull(_ value: AnyJSONValue) {
        #expect(value.isNull == false)
    }

    // MARK: - Accessor: stringValue

    @Test func stringValueExtractsWhenString() {
        #expect(AnyJSONValue.string("hello").stringValue == "hello")
        #expect(AnyJSONValue.string("").stringValue == "")
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .int(1),
        .double(1),
        .bool(true),
        .array([]),
        .dictionary([:]),
    ])
    func stringValueNilForNonString(_ value: AnyJSONValue) {
        #expect(value.stringValue == nil)
    }

    @Test func stringValuePreservesUnicodeAndEmoji() {
        let s = "héllo👨‍👩‍👧‍👦café\u{0301}"
        #expect(AnyJSONValue.string(s).stringValue == s)
    }

    // MARK: - Accessor: intValue

    @Test func intValueExtractsWhenInt() {
        #expect(AnyJSONValue.int(42).intValue == 42)
        #expect(AnyJSONValue.int(0).intValue == 0)
        #expect(AnyJSONValue.int(-7).intValue == -7)
        #expect(AnyJSONValue.int(.max).intValue == Int.max)
        #expect(AnyJSONValue.int(.min).intValue == Int.min)
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .string("1"),
        .double(1),
        .bool(true),
        .array([]),
        .dictionary([:]),
    ])
    func intValueNilForNonInt(_ value: AnyJSONValue) {
        #expect(value.intValue == nil)
    }

    // MARK: - Accessor: doubleValue

    @Test func doubleValueExtractsWhenDouble() {
        #expect(AnyJSONValue.double(3.5).doubleValue == 3.5)
        #expect(AnyJSONValue.double(0).doubleValue == 0)
        #expect(AnyJSONValue.double(-2.25).doubleValue == -2.25)
    }

    @Test func doubleValueExtremes() {
        #expect(AnyJSONValue.double(.greatestFiniteMagnitude).doubleValue == .greatestFiniteMagnitude)
        #expect(AnyJSONValue.double(.leastNonzeroMagnitude).doubleValue == .leastNonzeroMagnitude)
        #expect(AnyJSONValue.double(.infinity).doubleValue == .infinity)
        #expect(AnyJSONValue.double(-.infinity).doubleValue == -.infinity)
        #expect(AnyJSONValue.double(.nan).doubleValue?.isNaN == true)
    }

    @Test func doubleValuePreservesNegativeZeroSign() {
        // -0.0 == 0.0 numerically, but the sign bit must be preserved by the accessor.
        let extracted = AnyJSONValue.double(-0.0).doubleValue
        #expect(extracted == 0.0)
        #expect(extracted?.sign == .minus)
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .string("1.0"),
        .int(1),
        .bool(true),
        .array([]),
        .dictionary([:]),
    ])
    func doubleValueNilForNonDouble(_ value: AnyJSONValue) {
        #expect(value.doubleValue == nil)
    }

    // MARK: - Accessor: boolValue

    @Test func boolValueExtractsWhenBool() {
        #expect(AnyJSONValue.bool(true).boolValue == true)
        #expect(AnyJSONValue.bool(false).boolValue == false)
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .string("true"),
        .int(1),
        .int(0),
        .double(1),
        .array([]),
        .dictionary([:]),
    ])
    func boolValueNilForNonBool(_ value: AnyJSONValue) {
        #expect(value.boolValue == nil)
    }

    // MARK: - Accessor: arrayValue

    @Test func arrayValueExtractsWhenArray() throws {
        let arr: [AnyJSONValue] = [.int(1), .string("a"), .null]
        let extracted = try #require(AnyJSONValue.array(arr).arrayValue)
        #expect(extracted == arr)
        #expect(extracted.count == 3)
    }

    @Test func arrayValueEmptyArray() throws {
        let extracted = try #require(AnyJSONValue.array([]).arrayValue)
        #expect(extracted.isEmpty)
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .string("[]"),
        .int(1),
        .double(1),
        .bool(true),
        .dictionary([:]),
    ])
    func arrayValueNilForNonArray(_ value: AnyJSONValue) {
        #expect(value.arrayValue == nil)
    }

    // MARK: - Accessor: dictionaryValue

    @Test func dictionaryValueExtractsWhenDictionary() throws {
        let dict: [String: AnyJSONValue] = ["a": .int(1), "b": .bool(false)]
        let extracted = try #require(AnyJSONValue.dictionary(dict).dictionaryValue)
        #expect(extracted == dict)
        #expect(extracted["a"] == .int(1))
    }

    @Test func dictionaryValueEmptyDictionary() throws {
        let extracted = try #require(AnyJSONValue.dictionary([:]).dictionaryValue)
        #expect(extracted.isEmpty)
    }

    @Test(arguments: [
        AnyJSONValue.null,
        .string("{}"),
        .int(1),
        .double(1),
        .bool(true),
        .array([]),
    ])
    func dictionaryValueNilForNonDictionary(_ value: AnyJSONValue) {
        #expect(value.dictionaryValue == nil)
    }

    // MARK: - Hashable / Equatable

    @Test func equalSameCaseSameValue() {
        #expect(AnyJSONValue.int(5) == AnyJSONValue.int(5))
        #expect(AnyJSONValue.string("a") == AnyJSONValue.string("a"))
        #expect(AnyJSONValue.null == AnyJSONValue.null)
        #expect(AnyJSONValue.bool(true) == AnyJSONValue.bool(true))
        #expect(AnyJSONValue.double(3.5) == AnyJSONValue.double(3.5))
    }

    @Test func notEqualDifferentCaseSameUnderlyingNumber() {
        // Same numeric magnitude but different case must NOT be equal.
        #expect(AnyJSONValue.int(1) != AnyJSONValue.double(1))
        #expect(AnyJSONValue.bool(true) != AnyJSONValue.int(1))
        #expect(AnyJSONValue.string("1") != AnyJSONValue.int(1))
        #expect(AnyJSONValue.null != AnyJSONValue.bool(false))
        #expect(AnyJSONValue.double(0) != AnyJSONValue.bool(false))
        #expect(AnyJSONValue.array([]) != AnyJSONValue.dictionary([:]))
    }

    @Test func notEqualSameCaseDifferentValue() {
        #expect(AnyJSONValue.int(1) != AnyJSONValue.int(2))
        #expect(AnyJSONValue.double(1.0) != AnyJSONValue.double(1.5))
        #expect(AnyJSONValue.string("a") != AnyJSONValue.string("A"))
        #expect(AnyJSONValue.array([.int(1)]) != AnyJSONValue.array([.int(2)]))
        #expect(AnyJSONValue.array([.int(1)]) != AnyJSONValue.array([.int(1), .int(1)]))
        #expect(AnyJSONValue.dictionary(["a": .int(1)]) != AnyJSONValue.dictionary(["a": .int(2)]))
        #expect(AnyJSONValue.dictionary(["a": .int(1)]) != AnyJSONValue.dictionary(["b": .int(1)]))
    }

    @Test func nanDoubleIsNeverEqualToItself() {
        // NaN != NaN under IEEE semantics, which the synthesized Equatable inherits.
        #expect(AnyJSONValue.double(.nan) != AnyJSONValue.double(.nan))
    }

    @Test func hashConsistentWithEquality() {
        let a = AnyJSONValue.dictionary(["k": .array([.int(1), .string("x")])])
        let b = AnyJSONValue.dictionary(["k": .array([.int(1), .string("x")])])
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func usableAsSetElementAndDictionaryKey() {
        let set: Set<AnyJSONValue> = [.int(1), .int(1), .string("a"), .null, .null]
        // Duplicates collapse.
        #expect(set.count == 3)
        #expect(set.contains(.int(1)))
        #expect(set.contains(.null))
        #expect(!set.contains(.int(2)))

        let map: [AnyJSONValue: Int] = [.bool(true): 1, .bool(false): 2]
        #expect(map[.bool(true)] == 1)
        #expect(map[.bool(false)] == 2)
    }

    @Test func setDistinguishesCasesWithSameMagnitude() {
        // .int(1), .double(1), .bool(true), .string("1") are four distinct elements.
        let set: Set<AnyJSONValue> = [.int(1), .double(1), .bool(true), .string("1"), .int(1)]
        #expect(set.count == 4)
        #expect(set.contains(.int(1)))
        #expect(set.contains(.double(1)))
        #expect(set.contains(.bool(true)))
        #expect(set.contains(.string("1")))
    }

    @Test func nestedContainersUsableAsSetElements() {
        let set: Set<AnyJSONValue> = [
            .array([.int(1), .int(2)]),
            .array([.int(1), .int(2)]),
            .dictionary(["k": .null]),
            .dictionary(["k": .null]),
        ]
        #expect(set.count == 2)
        #expect(set.contains(.array([.int(1), .int(2)])))
        #expect(set.contains(.dictionary(["k": .null])))
    }

    // MARK: - Encoding

    @Test func encodeNullProducesJSONNull() throws {
        let data = try encode(.null)
        #expect(String(decoding: data, as: UTF8.self) == "null")
    }

    @Test func encodeBool() throws {
        #expect(String(decoding: try encode(.bool(true)), as: UTF8.self) == "true")
        #expect(String(decoding: try encode(.bool(false)), as: UTF8.self) == "false")
    }

    @Test func encodeInt() throws {
        #expect(String(decoding: try encode(.int(42)), as: UTF8.self) == "42")
        #expect(String(decoding: try encode(.int(-1)), as: UTF8.self) == "-1")
        #expect(String(decoding: try encode(.int(.max)), as: UTF8.self) == "\(Int.max)")
        #expect(String(decoding: try encode(.int(.min)), as: UTF8.self) == "\(Int.min)")
    }

    @Test func encodeString() throws {
        #expect(String(decoding: try encode(.string("hi")), as: UTF8.self) == "\"hi\"")
        #expect(String(decoding: try encode(.string("")), as: UTF8.self) == "\"\"")
    }

    @Test func encodeArray() throws {
        let data = try encode(.array([.int(1), .int(2), .null]))
        #expect(String(decoding: data, as: UTF8.self) == "[1,2,null]")
    }

    @Test func encodeDictionarySorted() throws {
        let value = AnyJSONValue.dictionary(["b": .int(2), "a": .int(1)])
        let data = try encode(value, sortKeys: true)
        #expect(String(decoding: data, as: UTF8.self) == "{\"a\":1,\"b\":2}")
    }

    @Test func encodeNonFiniteDoubleThrows() {
        // JSONEncoder cannot represent infinity/NaN by default; encode(to:) must propagate.
        #expect(throws: EncodingError.self) {
            _ = try encode(.double(.infinity))
        }
        #expect(throws: EncodingError.self) {
            _ = try encode(.double(-.infinity))
        }
        #expect(throws: EncodingError.self) {
            _ = try encode(.double(.nan))
        }
        // A non-finite double nested inside a container must also fail to encode.
        #expect(throws: EncodingError.self) {
            _ = try encode(.array([.int(1), .double(.infinity)]))
        }
    }

    // MARK: - Decoding (scalar fragments)

    @Test func decodeNull() throws {
        #expect(try decodeFragment("null") == .null)
    }

    @Test func decodeBoolTrueAndFalse() throws {
        #expect(try decodeFragment("true") == .bool(true))
        #expect(try decodeFragment("false") == .bool(false))
    }

    @Test func decodeIntegerBecomesIntCase() throws {
        // Integer literals are decoded as .int (Int decode succeeds before Double).
        let zero = try decodeFragment("0")
        #expect(zero == .int(0))
        #expect(caseTag(zero) == "int")
        #expect(try decodeFragment("42") == .int(42))
        #expect(try decodeFragment("-7") == .int(-7))
        // Boundary: Int.max / Int.min must decode as .int, not overflow to .double.
        #expect(try decodeFragment("\(Int.max)") == .int(.max))
        #expect(try decodeFragment("\(Int.min)") == .int(.min))
    }

    @Test func decodeFloatingPointBecomesDoubleCase() throws {
        let v = try decodeFragment("3.5")
        #expect(v == .double(3.5))
        #expect(caseTag(v) == "double")
        #expect(try decodeFragment("-2.25") == .double(-2.25))
    }

    @Test func decodeNegativeZeroFragmentBecomesInt() throws {
        // "-0.0" / "-0" are integral, so the Int-before-Double precedence yields .int(0).
        #expect(try decodeFragment("-0.0") == .int(0))
        #expect(try decodeFragment("-0") == .int(0))
        #expect(caseTag(try decodeFragment("-0.0")) == "int")
    }

    @Test func decodeOverflowingIntegerFallsBackToDouble() throws {
        // A whole number too large for Int64 cannot decode as Int, so it lands in .double.
        let huge = "100000000000000000000" // 1e20, > Int.max
        let value = try decodeFragment(huge)
        #expect(caseTag(value) == "double")
        #expect(value.doubleValue == 1e20)
        #expect(value.intValue == nil)
    }

    @Test func decodeStringFragment() throws {
        #expect(try decodeFragment("\"hello\"") == .string("hello"))
        #expect(try decodeFragment("\"\"") == .string(""))
    }

    @Test func decodeNestedObject() throws {
        let json = """
        {"name":"yuman","age":30,"active":true,"score":9.5,"tags":["a","b"],"extra":null}
        """
        let value = try decode(json)
        let dict = try #require(value.dictionaryValue)
        #expect(dict.count == 6)
        #expect(dict["name"] == .string("yuman"))
        #expect(dict["age"] == .int(30))
        #expect(dict["active"] == .bool(true))
        #expect(dict["score"] == .double(9.5))
        #expect(dict["tags"] == .array([.string("a"), .string("b")]))
        #expect(dict["extra"] == .null)
    }

    @Test func decodeNestedArrayOfMixedTypes() throws {
        let value = try decode("[1, 2.5, \"x\", true, null, {\"k\":1}, []]")
        let arr = try #require(value.arrayValue)
        #expect(arr.count == 7)
        #expect(arr[0] == .int(1))
        #expect(arr[1] == .double(2.5))
        #expect(arr[2] == .string("x"))
        #expect(arr[3] == .bool(true))
        #expect(arr[4] == .null)
        #expect(arr[5] == .dictionary(["k": .int(1)]))
        #expect(arr[6] == .array([]))
    }

    @Test func decodeEmptyContainers() throws {
        #expect(try decode("[]") == .array([]))
        #expect(try decode("{}") == .dictionary([:]))
    }

    @Test func decodeUnicodeAndEscapedString() throws {
        // \u escapes and a literal emoji must both decode to the same scalars.
        #expect(try decodeFragment("\"caf\\u00e9\"") == .string("café"))
        #expect(try decodeFragment("\"\\n\\t\\\"\"") == .string("\n\t\""))
        #expect(try decodeFragment("\"🚀\"") == .string("🚀"))
    }

    @Test func decodeObjectWithUnicodeKeys() throws {
        let value = try decode("{\"键\":1,\"🔑\":\"v\"}")
        let dict = try #require(value.dictionaryValue)
        #expect(dict["键"] == .int(1))
        #expect(dict["🔑"] == .string("v"))
    }

    // MARK: - Decoding errors

    @Test func decodeMalformedJSONThrows() {
        #expect(throws: (any Error).self) {
            try decodeFragment("{not valid json")
        }
    }

    @Test func decodeTruncatedThrows() {
        #expect(throws: (any Error).self) {
            try decodeFragment("[1, 2,")
        }
    }

    @Test func decodeEmptyDataThrows() {
        #expect(throws: (any Error).self) {
            try decodeFragment("")
        }
    }

    @Test func decodeTrailingGarbageThrows() {
        #expect(throws: (any Error).self) {
            try decodeFragment("42 trailing")
        }
        #expect(throws: (any Error).self) {
            try decodeFragment("[1,2]]")
        }
    }

    @Test func decodeNonFiniteLiteralThrows() {
        // Bare Infinity/NaN are not valid strict JSON and must fail to decode.
        #expect(throws: (any Error).self) {
            try decodeFragment("Infinity")
        }
        #expect(throws: (any Error).self) {
            try decodeFragment("NaN")
        }
    }

    // MARK: - Round trips

    @Test(arguments: [
        AnyJSONValue.null,
        .bool(true),
        .bool(false),
        .int(0),
        .int(-99),
        .int(.max),
        .int(.min),
        .double(3.14159),
        .double(0.5),
        .double(-2.25),
        .string("plain"),
        .string(""),
        .string("unicode héllo 👨‍👩‍👧‍👦 café\u{0301}"),
        .array([.int(1), .string("a"), .null, .bool(false)]),
        .array([]),
        .dictionary(["x": .int(1), "y": .array([.bool(true)])]),
        .dictionary([:]),
    ])
    func roundTripEncodeDecode(_ value: AnyJSONValue) throws {
        let data = try encode(value, sortKeys: true)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        #expect(decoded == value)
        #expect(caseTag(decoded) == caseTag(value))
    }

    @Test func roundTripDeeplyNested() throws {
        let value = AnyJSONValue.dictionary([
            "level1": .dictionary([
                "level2": .array([
                    .dictionary(["deep": .string("value")]),
                    .int(123),
                    .null,
                ]),
            ]),
        ])
        let data = try encode(value, sortKeys: true)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test func roundTripDictionaryWithUnicodeAndEmptyKeys() throws {
        let value = AnyJSONValue.dictionary([
            "": .int(0),
            "键": .string("值"),
            "🔑": .bool(true),
            "a.b/c": .null,
        ])
        let data = try encode(value, sortKeys: true)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        #expect(decoded == value)
        let dict = try #require(decoded.dictionaryValue)
        #expect(dict[""] == .int(0))
        #expect(dict["键"] == .string("值"))
    }

    @Test func roundTripStringFragmentPreservesContent() throws {
        // String that LOOKS like other JSON types must stay a string through round trip.
        for raw in ["true", "false", "null", "42", "3.14", "[1,2]", "{\"a\":1}", "-0.0"] {
            let value = AnyJSONValue.string(raw)
            let data = try encode(value)
            let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
            #expect(decoded == .string(raw), "raw=\(raw)")
            #expect(decoded.stringValue == raw)
            #expect(caseTag(decoded) == "string", "raw=\(raw)")
        }
    }

    @Test func wholeValuedDoubleDoesNotRoundTripAsDouble() throws {
        // SUSPECTED SOURCE BUG: a .double whose value is integral (e.g. -0.0, 2.0, 100.0)
        // is encoded by JSONEncoder as a plain integer JSON number ("-0", "2", ...).
        // On decode, init(from:) attempts Int.self BEFORE Double.self, so the value
        // comes back as .int rather than .double — the .double case is lost. We assert
        // the ACTUAL current behavior so this test documents (and pins) it; if the source
        // ever fixes precedence, this test will fail loudly and should be updated.
        let cases: [(AnyJSONValue, AnyJSONValue)] = [
            (.double(-0.0), .int(0)),
            (.double(2.0), .int(2)),
            (.double(100.0), .int(100)),
            (.double(-5.0), .int(-5)),
        ]
        for (input, expected) in cases {
            let data = try encode(input)
            let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
            #expect(decoded == expected, "input=\(input)")
            #expect(caseTag(decoded) == "int", "input=\(input)")
        }
    }

    // MARK: - Decode/accessor interaction (type inference on decode)

    @Test func decodedIntegerIsAccessibleViaIntValueNotDouble() throws {
        let value = try decodeFragment("5")
        #expect(value.intValue == 5)
        // It decoded as .int, so doubleValue must be nil.
        #expect(value.doubleValue == nil)
    }

    @Test func decodedFloatIsAccessibleViaDoubleValueNotInt() throws {
        let value = try decodeFragment("5.5")
        #expect(value.doubleValue == 5.5)
        #expect(value.intValue == nil)
    }

    @Test func decodedBoolIsAccessibleViaBoolValueNotInt() throws {
        // Bool decode is attempted before Int, so `true`/`false` never become .int(1)/.int(0).
        let t = try decodeFragment("true")
        #expect(t.boolValue == true)
        #expect(t.intValue == nil)
        let f = try decodeFragment("false")
        #expect(f.boolValue == false)
        #expect(f.intValue == nil)
    }

    // MARK: - Sendable / concurrency

    @Test func concurrentDecodeRoundTripsAreStable() async throws {
        let sample = AnyJSONValue.dictionary([
            "id": .int(7),
            "name": .string("concurrent"),
            "flags": .array([.bool(true), .bool(false), .null]),
            "ratio": .double(0.5),
        ])
        let data = try encode(sample, sortKeys: true)

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<500 {
                group.addTask {
                    guard let decoded = try? JSONDecoder().decode(AnyJSONValue.self, from: data) else {
                        return false
                    }
                    return decoded == sample
                }
            }
            var collected: [Bool] = []
            for await ok in group {
                collected.append(ok)
            }
            return collected
        }

        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 })
    }

    @Test func concurrentEncodeRoundTripsAreStable() async throws {
        // Encoding a shared Sendable value from many tasks must be byte-stable.
        let sample = AnyJSONValue.dictionary([
            "a": .int(1),
            "b": .array([.string("x"), .null, .bool(true)]),
            "c": .double(0.25),
        ])
        let expected = String(decoding: try encode(sample, sortKeys: true), as: UTF8.self)

        let outputs = await withTaskGroup(of: String?.self, returning: [String?].self) { group in
            for _ in 0..<300 {
                group.addTask {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.sortedKeys]
                    guard let d = try? encoder.encode(sample) else { return nil }
                    return String(decoding: d, as: UTF8.self)
                }
            }
            var collected: [String?] = []
            for await s in group {
                collected.append(s)
            }
            return collected
        }

        #expect(outputs.count == 300)
        #expect(outputs.allSatisfy { $0 == expected })
    }

    @Test func concurrentReadsOfSharedValueAreConsistent() async {
        // AnyJSONValue is a Sendable value type; sharing across tasks is safe.
        let shared = AnyJSONValue.array((0..<100).map { .int($0) })
        let sums = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
            for _ in 0..<200 {
                group.addTask {
                    (shared.arrayValue ?? []).compactMap(\.intValue).reduce(0, +)
                }
            }
            var collected: [Int] = []
            for await s in group {
                collected.append(s)
            }
            return collected
        }
        let expected = (0..<100).reduce(0, +)
        #expect(sums.count == 200)
        #expect(sums.allSatisfy { $0 == expected })
    }

    // MARK: - Large data (time-bounded)

    @Test func largeArrayRoundTrip() throws {
        let count = 100_000
        let big = AnyJSONValue.array((0..<count).map { .int($0) })
        let data = try encode(big)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        let arr = try #require(decoded.arrayValue)
        #expect(arr.count == count)
        #expect(arr.first == .int(0))
        #expect(arr.last == .int(count - 1))
        #expect(decoded == big)
    }

    @Test func largeDictionaryRoundTrip() throws {
        let count = 50_000
        var pairs: [String: AnyJSONValue] = [:]
        pairs.reserveCapacity(count)
        for i in 0..<count {
            pairs["k\(i)"] = .int(i)
        }
        let big = AnyJSONValue.dictionary(pairs)
        let data = try encode(big)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        let dict = try #require(decoded.dictionaryValue)
        #expect(dict.count == count)
        #expect(dict["k0"] == .int(0))
        #expect(dict["k\(count - 1)"] == .int(count - 1))
        #expect(decoded == big)
    }

    @Test func longStringRoundTrip() throws {
        let long = String(repeating: "λ漢字🚀\u{0301}", count: 20_000)
        let value = AnyJSONValue.string(long)
        let data = try encode(value)
        let decoded = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        #expect(decoded.stringValue == long)
        #expect(decoded == value)
    }
}
