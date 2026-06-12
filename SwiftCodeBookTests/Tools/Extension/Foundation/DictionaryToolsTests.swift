//
//  DictionaryToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/Dictionary+Tools.swift
//  Covers the public `Dictionary` extensions:
//    - func toJSONData() -> Data?
//    - func toJSONString() -> String?
//    - init?(plistFilePath: String)
//
//  SUSPECTED SOURCE BUG (toJSONData / toJSONString): the implementation calls
//  `try? JSONSerialization.data(withJSONObject: self)` WITHOUT first checking
//  `JSONSerialization.isValidJSONObject(self)`. For invalid inputs (Date,
//  non-finite Double, non-string keys, arbitrary NSObject values, ...)
//  `data(withJSONObject:)` raises an *Objective-C* `NSException`
//  (e.g. "Invalid type in JSON write", "Invalid (non-string) key in JSON
//  dictionary"), which `try?` does NOT convert to a Swift error — so the call
//  CRASHES the process instead of returning nil. Verified empirically on the
//  Xcode 26.x toolchain (the process terminates with NSInvalidArgumentException
//  even when the call is wrapped in `try?`). These tests therefore only feed
//  VALID JSON objects to those two functions (so the suite cannot crash) and
//  never assert the nil branch for invalid input, because that branch is
//  currently unreachable without crashing the whole test run. The `-> Data?`
//  optional return is, in practice, a dead nil branch for malformed input.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct DictionaryToolsTests {

    // MARK: - Helpers

    /// Creates a unique temporary directory and returns its URL. The caller is
    /// responsible for cleaning it up.
    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DictionaryToolsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a property list (XML or binary) to a file from a dictionary and returns the path.
    private static func writePlist(
        _ dict: [String: Any],
        in dir: URL,
        name: String = "dict.plist",
        format: PropertyListSerialization.PropertyListFormat = .xml
    ) throws -> String {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url.path
    }

    /// Parses a JSON string back into a dictionary keyed by String for assertions.
    private static func parseJSONObject(_ string: String) throws -> [String: Any] {
        let data = Data(string.utf8)
        let obj = try JSONSerialization.jsonObject(with: data)
        return try #require(obj as? [String: Any])
    }

    // MARK: - toJSONData: happy path

    @Test func toJSONDataProducesValidJSON() throws {
        let dict: [String: Any] = ["name": "yuman", "age": 30, "active": true]
        let data = try #require(dict.toJSONData())
        // Round-trip: deserializing yields an equivalent object.
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["name"] as? String == "yuman")
        #expect(obj["age"] as? Int == 30)
        #expect(obj["active"] as? Bool == true)
    }

    @Test func toJSONDataEmptyDictionary() throws {
        let dict: [String: Int] = [:]
        let data = try #require(dict.toJSONData())
        let string = try #require(String(data: data, encoding: .utf8))
        // An empty dictionary serializes to the empty JSON object.
        #expect(string == "{}")
    }

    @Test func toJSONDataSingleEntry() throws {
        let dict: [String: Int] = ["only": 1]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(obj == ["only": 1])
    }

    @Test func toJSONDataEmptyStringKeyAndValue() throws {
        // Boundary: empty-string key and empty-string value are both valid JSON.
        let dict: [String: String] = ["": "", "k": ""]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(obj == ["": "", "k": ""])
    }

    @Test func toJSONDataNestedStructures() throws {
        let dict: [String: Any] = [
            "list": [1, 2, 3],
            "nested": ["inner": "value"],
            "mixed": [["a": 1], ["b": 2]],
        ]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["list"] as? [Int] == [1, 2, 3])
        let nested = try #require(obj["nested"] as? [String: String])
        #expect(nested == ["inner": "value"])
        let mixed = try #require(obj["mixed"] as? [[String: Int]])
        #expect(mixed.count == 2)
        #expect(mixed[0] == ["a": 1])
        #expect(mixed[1] == ["b": 2])
    }

    @Test func toJSONDataNestedEmptyContainers() throws {
        // Boundary: empty nested array and empty nested object round-trip as empty.
        let dict: [String: Any] = ["arr": [Int](), "obj": [String: Int]()]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let arr = try #require(obj["arr"] as? [Any])
        let inner = try #require(obj["obj"] as? [String: Any])
        #expect(arr.isEmpty)
        #expect(inner.isEmpty)
    }

    @Test func toJSONDataNullValueViaNSNull() throws {
        // NSNull is a valid JSON value and should serialize to `null`.
        let dict: [String: Any] = ["maybe": NSNull()]
        let data = try #require(dict.toJSONData())
        let string = try #require(String(data: data, encoding: .utf8))
        #expect(string == "{\"maybe\":null}")
    }

    @Test func toJSONDataNumericTypes() throws {
        let dict: [String: Any] = [
            "int": 42,
            "double": 3.5,
            "negative": -7,
            "zeroInt": 0,
            "negDouble": -0.25,
        ]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["int"] as? Int == 42)
        #expect(obj["double"] as? Double == 3.5)
        #expect(obj["negative"] as? Int == -7)
        #expect(obj["zeroInt"] as? Int == 0)
        let negDouble = try #require(obj["negDouble"] as? Double)
        #expect(abs(negDouble - (-0.25)) < 1e-12)
    }

    @Test func toJSONDataIntExtremes() throws {
        let dict: [String: Int] = ["min": Int.min, "max": Int.max]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(obj["min"] == Int.min)
        #expect(obj["max"] == Int.max)
    }

    @Test func toJSONDataUnicodeAndEmoji() throws {
        // Combining characters, emoji, and CJK exercise the UTF-8 path.
        let dict: [String: String] = [
            "emoji": "👨‍👩‍👧‍👦🎉",
            "cjk": "中文测试",
            "combining": "e\u{0301}", // é as e + combining acute accent
        ]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(obj["emoji"] == "👨‍👩‍👧‍👦🎉")
        #expect(obj["cjk"] == "中文测试")
        #expect(obj["combining"] == "e\u{0301}")
    }

    @Test func toJSONDataUnicodeKeysRoundTrip() throws {
        // Unicode in keys (not just values) must survive serialization.
        let dict: [String: Int] = ["键🔑": 1, "ключ": 2]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(obj == ["键🔑": 1, "ключ": 2])
    }

    @Test func toJSONDataLargeDictionary() throws {
        // Large but time-bounded: 100_000 entries.
        var dict = [String: Int](minimumCapacity: 100_000)
        for i in 0..<100_000 {
            dict["k\(i)"] = i
        }
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(obj.count == 100_000)
        #expect(obj["k0"] == 0)
        #expect(obj["k99999"] == 99_999)
    }

    @Test func toJSONDataBoolsDistinctFromNumbers() throws {
        // Verify true/false survive the round trip as Bool, not as 1/0.
        let dict: [String: Bool] = ["yes": true, "no": false]
        let data = try #require(dict.toJSONData())
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Bool])
        #expect(obj == ["yes": true, "no": false])
    }

    // MARK: - toJSONString: happy path

    @Test func toJSONStringProducesParseableString() throws {
        let dict: [String: Any] = ["name": "yuman", "age": 30]
        let string = try #require(dict.toJSONString())
        let obj = try Self.parseJSONObject(string)
        #expect(obj["name"] as? String == "yuman")
        #expect(obj["age"] as? Int == 30)
    }

    @Test func toJSONStringEmptyDictionary() throws {
        let dict: [String: Int] = [:]
        let string = try #require(dict.toJSONString())
        #expect(string == "{}")
    }

    @Test func toJSONStringSingleEntry() throws {
        let dict: [String: Int] = ["only": 5]
        let string = try #require(dict.toJSONString())
        // JSONSerialization (no .prettyPrinted) emits compact output: no spaces.
        #expect(string == "{\"only\":5}")
    }

    @Test func toJSONStringIsUTF8DecodingOfJSONData() throws {
        // toJSONString should equal the UTF-8 decode of toJSONData for the SAME
        // dictionary instance (so key ordering cannot differ between the two).
        let dict: [String: Any] = ["k": "v", "n": 1, "list": [true, false]]
        let data = try #require(dict.toJSONData())
        let expected = try #require(String(data: data, encoding: .utf8))
        let string = try #require(dict.toJSONString())
        #expect(string == expected)
    }

    @Test func toJSONStringUnicodeRoundTrips() throws {
        let dict: [String: String] = ["greet": "你好 🌟"]
        let string = try #require(dict.toJSONString())
        let obj = try Self.parseJSONObject(string)
        #expect(obj["greet"] as? String == "你好 🌟")
    }

    // MARK: - init?(plistFilePath:): happy path

    @Test func initFromXMLPlistStringValues() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: Any] = ["name": "yuman", "city": "Seattle"]
        let path = try Self.writePlist(source, in: dir, format: .xml)

        let dict = try #require([String: String](plistFilePath: path))
        #expect(dict == ["name": "yuman", "city": "Seattle"])
    }

    @Test func initFromBinaryPlistStringValues() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: Any] = ["a": "1", "b": "2"]
        let path = try Self.writePlist(source, in: dir, name: "binary.plist", format: .binary)

        let dict = try #require([String: String](plistFilePath: path))
        #expect(dict == ["a": "1", "b": "2"])
    }

    @Test func initFromPlistEmptyDictionary() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist([:], in: dir)
        let dict = try #require([String: String](plistFilePath: path))
        #expect(dict.isEmpty)
    }

    @Test func initFromPlistSingleEntry() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist(["solo": "value"], in: dir)
        let dict = try #require([String: String](plistFilePath: path))
        #expect(dict == ["solo": "value"])
    }

    @Test func initFromPlistIntValuesCompatibleCast() throws {
        // Positive counterpart to the incompatible-value-type test: when the
        // plist values are integers, reading as [String: Int] succeeds.
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = try Self.writePlist(["a": 1, "b": 2], in: dir)
        let dict = try #require([String: Int](plistFilePath: path))
        #expect(dict == ["a": 1, "b": 2])
    }

    @Test func initFromPlistAnyValuesPreservesTypes() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: Any] = [
            "string": "hello",
            "int": 42,
            "double": 1.5,
            "bool": true,
            "array": [1, 2, 3],
            "data": Data([0x01, 0x02]),
            "nested": ["inner": "v"],
        ]
        let path = try Self.writePlist(source, in: dir)

        let dict = try #require([String: Any](plistFilePath: path))
        #expect(dict["string"] as? String == "hello")
        #expect(dict["int"] as? Int == 42)
        #expect(dict["double"] as? Double == 1.5)
        #expect(dict["bool"] as? Bool == true)
        #expect(dict["array"] as? [Int] == [1, 2, 3])
        #expect(dict["data"] as? Data == Data([0x01, 0x02]))
        #expect(dict["nested"] as? [String: String] == ["inner": "v"])
    }

    @Test func initFromBinaryPlistNestedContainers() throws {
        // Nested dictionary + array values survive the binary plist round trip.
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: Any] = ["outer": ["inner": "v"], "nums": [1, 2, 3]]
        let path = try Self.writePlist(source, in: dir, name: "nested.plist", format: .binary)

        let dict = try #require([String: Any](plistFilePath: path))
        #expect(dict["outer"] as? [String: String] == ["inner": "v"])
        #expect(dict["nums"] as? [Int] == [1, 2, 3])
    }

    @Test func initFromPlistUnicodeKeysAndValues() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: Any] = ["键": "值 🎈", "emoji🍕": "pizza"]
        let path = try Self.writePlist(source, in: dir)

        let dict = try #require([String: String](plistFilePath: path))
        #expect(dict["键"] == "值 🎈")
        #expect(dict["emoji🍕"] == "pizza")
    }

    // MARK: - init?(plistFilePath:): failure branches

    @Test func initFromNonexistentPathReturnsNil() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).plist").path
        #expect([String: String](plistFilePath: path) == nil)
    }

    @Test func initFromEmptyPathReturnsNil() throws {
        #expect([String: String](plistFilePath: "") == nil)
    }

    @Test func initFromDirectoryPathReturnsNil() throws {
        // A directory (not a regular plist file) cannot be parsed as a dictionary.
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect([String: String](plistFilePath: dir.path) == nil)
    }

    @Test func initFromNonPlistFileReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Write arbitrary non-plist bytes.
        let url = dir.appendingPathComponent("garbage.plist")
        try Data("this is not a plist".utf8).write(to: url)

        #expect([String: String](plistFilePath: url.path) == nil)
    }

    @Test func initFromEmptyFileReturnsNil() throws {
        // Boundary: a zero-byte file is not a valid plist.
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("empty.plist")
        try Data().write(to: url)

        #expect([String: String](plistFilePath: url.path) == nil)
    }

    @Test func initFromArrayPlistRootReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // A plist whose root is an array cannot be read by NSDictionary(contentsOfFile:).
        let arrayData = try PropertyListSerialization.data(
            fromPropertyList: [1, 2, 3], format: .xml, options: 0
        )
        let url = dir.appendingPathComponent("array.plist")
        try arrayData.write(to: url)

        #expect([String: String](plistFilePath: url.path) == nil)
    }

    @Test func initFromPlistWithIncompatibleValueTypeReturnsNil() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // File contains string values, but we attempt to read it as [String: Int].
        // The cast `as? [Key: Value]` fails because the value types don't match,
        // so the initializer returns nil.
        let path = try Self.writePlist(["k": "stringValue"], in: dir)
        #expect([String: Int](plistFilePath: path) == nil)
    }

    // MARK: - Round-trip via plist (write -> read)

    @Test func plistRoundTripStringDictionary() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original: [String: String] = [
            "alpha": "a",
            "beta": "b",
            "gamma": "c",
        ]
        // Write the dictionary itself out as a plist, then read it back.
        let data = try PropertyListSerialization.data(
            fromPropertyList: original, format: .xml, options: 0
        )
        let url = dir.appendingPathComponent("roundtrip.plist")
        try data.write(to: url)

        let restored = try #require([String: String](plistFilePath: url.path))
        #expect(restored == original)
    }

    // MARK: - Concurrency

    @Test func toJSONDataIsThreadSafeUnderConcurrency() async throws {
        // Dictionary value-type semantics: serializing the same dictionary from
        // many concurrent tasks must always yield consistent, parseable output.
        let dict: [String: Int] = ["a": 1, "b": 2, "c": 3, "d": 4]

        let results: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    guard let data = dict.toJSONData(),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Int]
                    else { return false }
                    return obj == ["a": 1, "b": 2, "c": 3, "d": 4]
                }
            }
            var collected = [Bool]()
            for await ok in group { collected.append(ok) }
            return collected
        }

        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 })
    }

    @Test func toJSONStringIsThreadSafeUnderConcurrency() async throws {
        let dict: [String: String] = ["x": "1", "y": "2"]

        let strings: [String] = await withTaskGroup(of: String?.self) { group in
            for _ in 0..<300 {
                group.addTask { dict.toJSONString() }
            }
            var collected = [String]()
            for await s in group { if let s { collected.append(s) } }
            return collected
        }

        #expect(strings.count == 300)
        // Every produced string must parse back to the same object.
        for s in strings {
            let obj = try Self.parseJSONObject(s)
            #expect(obj["x"] as? String == "1")
            #expect(obj["y"] as? String == "2")
        }
    }

    @Test func plistInitIsThreadSafeUnderConcurrency() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source: [String: String] = ["p": "1", "q": "2", "r": "3"]
        let path = try Self.writePlist(source, in: dir)

        let oks: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    guard let dict = [String: String](plistFilePath: path) else { return false }
                    return dict == ["p": "1", "q": "2", "r": "3"]
                }
            }
            var collected = [Bool]()
            for await ok in group { collected.append(ok) }
            return collected
        }

        #expect(oks.count == 200)
        #expect(oks.allSatisfy { $0 })
    }
}
