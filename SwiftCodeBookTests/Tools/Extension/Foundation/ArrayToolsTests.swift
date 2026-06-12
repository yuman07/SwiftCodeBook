//
//  ArrayToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/Extension/Foundation/Array+Tools.swift
//  Exercises the public Array extensions:
//    - toJSONData() / toJSONString()
//    - safeValue(at:)
//    - init?(plistFilePath:)
//    - removingDuplicates() for Element: Equatable and Element: Hashable
//
//  SUSPECTED SOURCE BUG (toJSONData / toJSONString): the implementation calls
//  `try? JSONSerialization.data(withJSONObject: self)` WITHOUT first checking
//  `JSONSerialization.isValidJSONObject(self)`. For invalid inputs (Date,
//  non-finite Double, ...) `data(withJSONObject:)` raises an *Objective-C*
//  `NSException` ("Invalid type in JSON write"), which `try?` does NOT convert
//  to a Swift error — so the call CRASHES the process instead of returning nil.
//  Verified empirically on this toolchain (Xcode 26). These tests therefore only
//  feed VALID JSON objects to those two functions and never assert the nil branch
//  for invalid input, because that branch is unreachable without crashing the
//  whole test target.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct ArrayToolsTests {

    // MARK: - Helpers

    /// Creates a unique temporary directory and returns its URL. The caller is
    /// responsible for cleaning it up (typically via `defer`).
    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArrayToolsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes an NSArray-compatible object to a plist file and returns its path.
    /// Uses property list serialization so the exact on-disk format is controlled.
    private static func writePlist(
        _ array: NSArray,
        in dir: URL,
        name: String = "data.plist",
        format: PropertyListSerialization.PropertyListFormat = .xml
    ) throws -> String {
        let url = dir.appendingPathComponent(name)
        let data = try PropertyListSerialization.data(fromPropertyList: array, format: format, options: 0)
        try data.write(to: url)
        return url.path
    }

    // MARK: - toJSONData

    @Test func toJSONDataValidArrayOfStrings() throws {
        let array = ["a", "b", "c"]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [String])
        #expect(decoded == array)
    }

    @Test func toJSONDataValidArrayOfInts() throws {
        let array = [1, 2, 3, -5, 0]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [Int])
        #expect(decoded == array)
    }

    @Test func toJSONDataIntExtremes() throws {
        let array = [Int.min, -1, 0, 1, Int.max]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [Int])
        #expect(decoded == array)
    }

    @Test func toJSONDataEmptyArray() throws {
        let array: [Int] = []
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [Int])
        #expect(decoded.isEmpty)
        // Empty JSON array serializes to the two-byte "[]".
        #expect(String(data: data, encoding: .utf8) == "[]")
    }

    @Test func toJSONDataNestedStructures() throws {
        let array: [[String: Int]] = [["x": 1], ["y": 2]]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Int]])
        #expect(decoded.count == 2)
        #expect(decoded[0]["x"] == 1)
        #expect(decoded[1]["y"] == 2)
    }

    @Test func toJSONDataNestedArrays() throws {
        let array: [[Int]] = [[1, 2], [], [3]]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [[Int]])
        #expect(decoded == [[1, 2], [], [3]])
    }

    @Test func toJSONDataFiniteDoubleExtremes() throws {
        // greatestFiniteMagnitude / -greatestFiniteMagnitude / 0 are all VALID JSON
        // numbers (unlike NaN/infinity, which would crash the buggy source).
        let array: [Double] = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, 0.0]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [Double])
        #expect(decoded.count == 3)
        #expect(decoded[2] == 0.0)
        #expect(decoded[0] == Double.greatestFiniteMagnitude)
        #expect(decoded[1] == -Double.greatestFiniteMagnitude)
    }

    @Test func toJSONDataBoolsSurviveAsBool() throws {
        // Confirm true/false round-trip as Bool, not as 1/0.
        let array: [Bool] = [true, false, true]
        let data = try #require(array.toJSONData())
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [Bool])
        #expect(decoded == [true, false, true])
    }

    // MARK: - toJSONString

    @Test func toJSONStringValidArray() throws {
        let array = [1, 2, 3]
        let string = try #require(array.toJSONString())
        // No insignificant whitespace is produced by JSONSerialization.
        #expect(string == "[1,2,3]")
    }

    @Test func toJSONStringEmptyArray() throws {
        let array: [String] = []
        let string = try #require(array.toJSONString())
        #expect(string == "[]")
    }

    @Test func toJSONStringIsUTF8DecodingOfJSONData() throws {
        // toJSONString must equal the UTF-8 decode of toJSONData.
        let array: [Int] = [10, 20, 30]
        let data = try #require(array.toJSONData())
        let expected = try #require(String(data: data, encoding: .utf8))
        let string = try #require(array.toJSONString())
        #expect(string == expected)
    }

    @Test func toJSONStringUnicodeAndEmoji() throws {
        let array = ["héllo", "😀", "e\u{0301}"] // combining acute accent
        let string = try #require(array.toJSONString())
        // Round-trip back through JSON to confirm fidelity rather than exact escaping.
        let data = try #require(string.data(using: .utf8))
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [String])
        #expect(decoded == array)
    }

    @Test func toJSONStringRoundTrip() throws {
        let original = ["one", "two", "three"]
        let string = try #require(original.toJSONString())
        let data = try #require(string.data(using: .utf8))
        let decoded = try #require(JSONSerialization.jsonObject(with: data) as? [String])
        #expect(decoded == original)
    }

    // NOTE: The nil/invalid-input branch of toJSONData/toJSONString is intentionally
    // NOT tested. JSONSerialization.data(withJSONObject:) raises an Objective-C
    // NSException (not a Swift error) for Date / NaN / infinity, which `try?` cannot
    // catch — asserting that branch would crash the whole test target. See the file
    // header comment for details.

    // MARK: - safeValue(at:)

    @Test func safeValueValidIndices() {
        let array = [10, 20, 30]
        #expect(array.safeValue(at: 0) == 10)
        #expect(array.safeValue(at: 1) == 20)
        #expect(array.safeValue(at: 2) == 30)
    }

    @Test func safeValueFirstAndLast() {
        let array = ["a", "b", "c", "d"]
        #expect(array.safeValue(at: 0) == "a")
        #expect(array.safeValue(at: array.count - 1) == "d")
    }

    @Test(arguments: [-1, -100, Int.min, 3, 4, 100, Int.max])
    func safeValueOutOfBoundsReturnsNil(index: Int) {
        let array = [1, 2, 3]
        #expect(array.safeValue(at: index) == nil)
    }

    @Test func safeValueEmptyArray() {
        let array: [Int] = []
        #expect(array.safeValue(at: 0) == nil)
        #expect(array.safeValue(at: -1) == nil)
        #expect(array.safeValue(at: Int.max) == nil)
        #expect(array.safeValue(at: Int.min) == nil)
    }

    @Test func safeValueSingleElement() {
        let array = [42]
        #expect(array.safeValue(at: 0) == 42)
        #expect(array.safeValue(at: 1) == nil)
        #expect(array.safeValue(at: -1) == nil)
    }

    @Test func safeValueOffByOneAtCount() {
        let array = [1, 2, 3]
        // index == count is out of bounds (count is not a valid index)
        #expect(array.safeValue(at: 3) == nil)
        // index == count - 1 is the last valid element
        #expect(array.safeValue(at: 2) == 3)
    }

    @Test func safeValueOptionalElementsDistinguishNilFromMiss() {
        // Element is Int?; a stored nil should be returned as .some(nil),
        // i.e. the result is Optional<Optional<Int>> == .some(.none).
        let array: [Int?] = [nil, 5, nil]
        let result0 = array.safeValue(at: 0)
        // In-bounds -> outer optional is .some, inner is .none.
        #expect(result0 == .some(.none))
        #expect(array.safeValue(at: 1) == .some(.some(5)))
        // Out of bounds -> outer optional is .none.
        #expect(array.safeValue(at: 9) == .none)
        #expect(array.safeValue(at: 2) == .some(.none))
    }

    @Test func safeValueLargeArray() {
        let array = Array(0..<100_000)
        #expect(array.safeValue(at: 0) == 0)
        #expect(array.safeValue(at: 99_999) == 99_999)
        #expect(array.safeValue(at: 100_000) == nil)
        #expect(array.safeValue(at: 50_000) == 50_000)
    }

    @Test func safeValueConcurrentReadsAreConsistent() async {
        let array = Array(0..<1_000)
        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<1_000 {
                group.addTask {
                    array.safeValue(at: i) == i
                }
            }
            // Also stress a few guaranteed out-of-bounds reads concurrently.
            for badIndex in [-1, 1_000, Int.max, Int.min] {
                group.addTask {
                    array.safeValue(at: badIndex) == nil
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }

    // MARK: - init?(plistFilePath:)

    @Test func initFromPlistStringArray() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist(["alpha", "beta", "gamma"] as NSArray, in: dir)
        let array = try #require([String](plistFilePath: path))
        #expect(array == ["alpha", "beta", "gamma"])
    }

    @Test func initFromPlistIntArray() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist([1, 2, 3] as NSArray, in: dir)
        // Plist numbers come back as NSNumber; bridging to [Int] succeeds.
        let array = try #require([Int](plistFilePath: path))
        #expect(array == [1, 2, 3])
    }

    @Test func initFromBinaryPlistStringArray() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist(["a", "b"] as NSArray, in: dir, name: "binary.plist", format: .binary)
        let array = try #require([String](plistFilePath: path))
        #expect(array == ["a", "b"])
    }

    @Test func initFromPlistEmptyArray() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist([] as NSArray, in: dir)
        let array = try #require([String](plistFilePath: path))
        #expect(array == [])
    }

    @Test func initFromPlistUnicodeStringArray() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = ["中文", "emoji🍕", "e\u{0301}"]
        let path = try Self.writePlist(source as NSArray, in: dir)
        let array = try #require([String](plistFilePath: path))
        #expect(array == source)
    }

    @Test func initFromPlistNonexistentPathReturnsNil() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).plist").path
        #expect([String](plistFilePath: path) == nil)
    }

    @Test func initFromPlistEmptyPathReturnsNil() {
        #expect([String](plistFilePath: "") == nil)
    }

    @Test func initFromPlistTypeMismatchReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // File contains strings but we ask for [Int]; the `as? [Int]` cast fails.
        let path = try Self.writePlist(["x", "y"] as NSArray, in: dir)
        #expect([Int](plistFilePath: path) == nil)
    }

    @Test func initFromPlistDictionaryRootReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // A plist whose root is a dictionary cannot be read by NSArray(contentsOfFile:).
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["k": "v"], format: .xml, options: 0
        )
        let url = dir.appendingPathComponent("dict.plist")
        try data.write(to: url)
        #expect([String](plistFilePath: url.path) == nil)
    }

    @Test func initFromPlistGarbageFileReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("garbage.plist")
        try Data("this is not a plist".utf8).write(to: url)
        #expect([String](plistFilePath: url.path) == nil)
    }

    @Test func initFromPlistRoundTrip() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = ["one", "two", "three", "four"]
        let path = try Self.writePlist(original as NSArray, in: dir)
        let array = try #require([String](plistFilePath: path))
        #expect(array == original)
    }

    @Test func initFromPlistIsThreadSafeUnderConcurrency() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = ["p", "q", "r"]
        let path = try Self.writePlist(source as NSArray, in: dir)

        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    [String](plistFilePath: path) == ["p", "q", "r"]
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }

    // MARK: - removingDuplicates() (Equatable, via non-Hashable element)

    // A struct that is Equatable but NOT Hashable to force the Equatable overload
    // to be selected. Sendable is synthesized (Int + String are Sendable), enabling
    // its use in concurrency stress tests.
    private struct EquatableOnly: Equatable, Sendable {
        let id: Int
        let tag: String
    }

    @Test func removingDuplicatesEquatablePreservesOrder() {
        let array = [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 2, tag: "b"),
            EquatableOnly(id: 1, tag: "a"), // duplicate of first
            EquatableOnly(id: 3, tag: "c"),
            EquatableOnly(id: 2, tag: "b"), // duplicate of second
        ]
        let result = array.removingDuplicates()
        #expect(result == [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 2, tag: "b"),
            EquatableOnly(id: 3, tag: "c"),
        ])
    }

    @Test func removingDuplicatesEquatableEmpty() {
        let array: [EquatableOnly] = []
        #expect(array.removingDuplicates() == [])
    }

    @Test func removingDuplicatesEquatableSingleElement() {
        let array = [EquatableOnly(id: 7, tag: "z")]
        // count <= 1 short-circuits and returns self unchanged.
        #expect(array.removingDuplicates() == array)
    }

    @Test func removingDuplicatesEquatableAllSame() {
        let e = EquatableOnly(id: 0, tag: "same")
        let array = [e, e, e, e, e]
        #expect(array.removingDuplicates() == [e])
    }

    @Test func removingDuplicatesEquatableNoDuplicates() {
        let array = [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 2, tag: "b"),
            EquatableOnly(id: 3, tag: "c"),
        ]
        #expect(array.removingDuplicates() == array)
    }

    @Test func removingDuplicatesEquatableDistinguishesByAllStoredProperties() {
        // Same id, different tag => not equal => both kept.
        let array = [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 1, tag: "b"),
            EquatableOnly(id: 1, tag: "a"), // dup of first only
        ]
        #expect(array.removingDuplicates() == [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 1, tag: "b"),
        ])
    }

    @Test func removingDuplicatesEquatableDoesNotMutateOriginal() {
        let array = [EquatableOnly(id: 1, tag: "a"), EquatableOnly(id: 1, tag: "a")]
        _ = array.removingDuplicates()
        #expect(array.count == 2) // original unchanged
    }

    @Test func removingDuplicatesEquatableConcurrent() async {
        let array = [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 2, tag: "b"),
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 3, tag: "c"),
        ]
        let expected = [
            EquatableOnly(id: 1, tag: "a"),
            EquatableOnly(id: 2, tag: "b"),
            EquatableOnly(id: 3, tag: "c"),
        ]
        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<300 {
                group.addTask {
                    array.removingDuplicates() == expected
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }

    // MARK: - removingDuplicates() (Hashable)

    @Test func removingDuplicatesHashableInts() {
        let array = [1, 2, 2, 3, 1, 4, 3, 5]
        let result = array.removingDuplicates()
        #expect(result == [1, 2, 3, 4, 5]) // first-seen order preserved
    }

    @Test func removingDuplicatesHashableStrings() {
        let array = ["apple", "banana", "apple", "cherry", "banana"]
        #expect(array.removingDuplicates() == ["apple", "banana", "cherry"])
    }

    @Test func removingDuplicatesHashableEmpty() {
        let array: [Int] = []
        #expect(array.removingDuplicates() == [])
    }

    @Test func removingDuplicatesHashableSingleElement() {
        let array = [99]
        #expect(array.removingDuplicates() == [99])
    }

    @Test func removingDuplicatesHashableTwoIdentical() {
        let array = [5, 5]
        // count > 1 so it does run the set-based path; collapses to one.
        #expect(array.removingDuplicates() == [5])
    }

    @Test func removingDuplicatesHashableTwoDistinct() {
        let array = [5, 9]
        #expect(array.removingDuplicates() == [5, 9])
    }

    @Test func removingDuplicatesHashableNegativesAndZero() {
        let array = [0, -1, 0, -1, 2, -1]
        #expect(array.removingDuplicates() == [0, -1, 2])
    }

    @Test func removingDuplicatesHashableAllSame() {
        let array = Array(repeating: "x", count: 1_000)
        #expect(array.removingDuplicates() == ["x"])
    }

    @Test func removingDuplicatesHashableUnicodeStrings() {
        let array = ["😀", "😀", "café", "cafe\u{0301}", "café"]
        let result = array.removingDuplicates()
        // "café" (precomposed) and "cafe\u{0301}" (decomposed) compare equal as
        // Swift Strings (canonical equivalence), so the decomposed form is dropped.
        #expect(result == ["😀", "café"])
    }

    @Test func removingDuplicatesHashableLargeArrayWithDuplicates() {
        // 100k elements, each value appears twice -> 50k unique, order preserved.
        var array: [Int] = []
        array.reserveCapacity(100_000)
        for i in 0..<50_000 { array.append(i) }
        for i in 0..<50_000 { array.append(i) }
        let result = array.removingDuplicates()
        #expect(result.count == 50_000)
        #expect(result.first == 0)
        #expect(result.last == 49_999)
        #expect(result == Array(0..<50_000))
    }

    @Test func removingDuplicatesHashableLargeAllUnique() {
        let array = Array(0..<100_000)
        let result = array.removingDuplicates()
        #expect(result.count == 100_000)
        #expect(result == array)
    }

    @Test func removingDuplicatesHashableDoesNotMutateOriginal() {
        let array = [1, 1, 2, 2, 3, 3]
        _ = array.removingDuplicates()
        #expect(array == [1, 1, 2, 2, 3, 3])
    }

    @Test func removingDuplicatesHashableConcurrent() async {
        let array = [1, 2, 2, 3, 3, 3, 4, 1, 5]
        let expected = [1, 2, 3, 4, 5]
        let allMatched = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    array.removingDuplicates() == expected
                }
            }
            return await group.reduce(into: true) { $0 = $0 && $1 }
        }
        #expect(allMatched)
    }
}
