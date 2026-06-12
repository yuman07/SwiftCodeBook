//
//  URLToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/URL+Tools.swift
//  Covers the public `URL` extension:
//    - var queryDictionary: [String: String]
//    - func removingQueryItems(where:) rethrows -> URL
//    - func removingAllQueryItems() -> URL
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct URLToolsTests {

    // MARK: - Helpers

    private static func url(_ string: String) -> URL {
        // Most strings under test are well-formed; force-unwrap is fine for fixtures.
        URL(string: string)!
    }

    private enum SampleError: Error { case boom }

    // MARK: - queryDictionary: happy path

    @Test func queryDictionarySingleItem() {
        let u = Self.url("https://example.com/path?a=1")
        #expect(u.queryDictionary == ["a": "1"])
    }

    @Test func queryDictionaryMultipleItems() {
        let u = Self.url("https://example.com/path?a=1&b=2&c=3")
        #expect(u.queryDictionary == ["a": "1", "b": "2", "c": "3"])
    }

    @Test func queryDictionaryNoQuery() {
        let u = Self.url("https://example.com/path")
        #expect(u.queryDictionary.isEmpty)
    }

    @Test func queryDictionaryEmptyQueryAfterQuestionMark() {
        // "https://example.com/path?" -> URLComponents reports queryItems == nil
        let u = Self.url("https://example.com/path?")
        #expect(u.queryDictionary.isEmpty)
    }

    // MARK: - queryDictionary: value edge cases

    @Test func queryDictionaryEmptyValue() {
        // "a=" yields an item whose value is "" (non-nil), so it IS included.
        let u = Self.url("https://example.com/path?a=")
        #expect(u.queryDictionary == ["a": ""])
    }

    @Test func queryDictionaryFlagWithoutEqualsIsDropped() {
        // "a" with no "=" -> URLQueryItem.value == nil -> dropped by the `if let`.
        let u = Self.url("https://example.com/path?a")
        #expect(u.queryDictionary.isEmpty)
    }

    @Test func queryDictionaryMixedNilAndNonNilValues() {
        // "flag" has nil value (dropped); "x=10" kept; "y=" kept as "".
        let u = Self.url("https://example.com/path?flag&x=10&y=")
        #expect(u.queryDictionary == ["x": "10", "y": ""])
    }

    @Test func queryDictionaryDuplicateNameLastWins() {
        // reduce(into:) overwrites: the last occurrence's value wins.
        let u = Self.url("https://example.com/path?a=1&a=2&a=3")
        #expect(u.queryDictionary == ["a": "3"])
    }

    @Test func queryDictionaryDuplicateNameLastNilDoesNotOverwrite() {
        // Last "a" has nil value so the `if let` skips it; the prior "a=1" stays.
        let u = Self.url("https://example.com/path?a=1&a")
        #expect(u.queryDictionary == ["a": "1"])
    }

    @Test func queryDictionaryPercentEncodedValueIsDecoded() {
        // %20 -> space, %26 -> & . URLComponents decodes these in .value.
        let u = Self.url("https://example.com/path?name=John%20Doe&op=a%26b")
        #expect(u.queryDictionary == ["name": "John Doe", "op": "a&b"])
    }

    @Test func queryDictionaryPlusIsNotDecodedAsSpace() {
        // URLComponents does NOT treat "+" as a space; it stays literal "+".
        let u = Self.url("https://example.com/path?q=a+b")
        #expect(u.queryDictionary == ["q": "a+b"])
    }

    @Test func queryDictionaryUnicodeValue() {
        let u = Self.url("https://example.com/path?emoji=%F0%9F%98%80&zh=%E4%BD%A0%E5%A5%BD")
        #expect(u.queryDictionary == ["emoji": "\u{1F600}", "zh": "你好"])
    }

    @Test func queryDictionaryEqualsInsideValuePreserved() {
        // "k=a=b" -> name "k", value "a=b".
        let u = Self.url("https://example.com/path?k=a=b")
        #expect(u.queryDictionary == ["k": "a=b"])
    }

    @Test func queryDictionaryFileURL() {
        // file URLs have no query; should be empty, no crash.
        let u = URL(fileURLWithPath: "/tmp/some/file.txt")
        #expect(u.queryDictionary.isEmpty)
    }

    @Test func queryDictionaryWithFragment() {
        // Fragment should not leak into the query dictionary.
        let u = Self.url("https://example.com/path?a=1#section")
        #expect(u.queryDictionary == ["a": "1"])
    }

    // MARK: - queryDictionary: large data

    @Test func queryDictionaryLargeNumberOfItems() throws {
        let count = 5_000
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "example.com"
        comps.path = "/big"
        comps.queryItems = (0..<count).map { URLQueryItem(name: "k\($0)", value: "v\($0)") }
        let u = try #require(comps.url)
        let dict = u.queryDictionary
        #expect(dict.count == count)
        #expect(dict["k0"] == "v0")
        #expect(dict["k\(count - 1)"] == "v\(count - 1)")
    }

    // MARK: - removingQueryItems(where:): basic removal

    @Test func removingQueryItemsRemovesMatching() throws {
        let u = Self.url("https://example.com/path?a=1&b=2&c=3")
        let result = u.removingQueryItems { $0.name == "b" }
        #expect(result.queryDictionary == ["a": "1", "c": "3"])
        // Host/path preserved.
        #expect(result.host == "example.com")
        #expect(result.path == "/path")
    }

    @Test func removingQueryItemsRemovesNoneWhenPredicateAlwaysFalse() {
        let u = Self.url("https://example.com/path?a=1&b=2")
        let result = u.removingQueryItems { _ in false }
        #expect(result.queryDictionary == ["a": "1", "b": "2"])
    }

    @Test func removingQueryItemsRemovesAllWhenPredicateAlwaysTrue() throws {
        // When all items removed, queryItems set to nil -> no "?" in the URL.
        let u = Self.url("https://example.com/path?a=1&b=2")
        let result = u.removingQueryItems { _ in true }
        #expect(result.queryDictionary.isEmpty)
        #expect(result.query == nil)
        let absolute = result.absoluteString
        #expect(!absolute.contains("?"))
        #expect(absolute == "https://example.com/path")
    }

    @Test func removingQueryItemsOnURLWithoutQuery() {
        let u = Self.url("https://example.com/path")
        let result = u.removingQueryItems { _ in true }
        #expect(result.query == nil)
        #expect(result.absoluteString == "https://example.com/path")
    }

    @Test func removingQueryItemsByValuePredicate() throws {
        let u = Self.url("https://example.com/path?a=keep&b=drop&c=keep&d=drop")
        let result = u.removingQueryItems { $0.value == "drop" }
        #expect(result.queryDictionary == ["a": "keep", "c": "keep"])
    }

    @Test func removingQueryItemsPreservesNilValuedItems() throws {
        // A flag item "flag" (nil value) that is NOT removed should survive.
        // It won't appear in queryDictionary (nil value) but must be in the URL.
        let u = Self.url("https://example.com/path?flag&a=1")
        let result = u.removingQueryItems { $0.name == "a" }
        let comps = try #require(URLComponents(url: result, resolvingAgainstBaseURL: true))
        let items = try #require(comps.queryItems)
        #expect(items.count == 1)
        #expect(items.first?.name == "flag")
        #expect(items.first?.value == nil)
    }

    @Test func removingQueryItemsKeepsDuplicatesNotMatched() throws {
        // Two "a" items; remove only "b". Both "a" items preserved (count check).
        let u = Self.url("https://example.com/path?a=1&a=2&b=3")
        let result = u.removingQueryItems { $0.name == "b" }
        let comps = try #require(URLComponents(url: result, resolvingAgainstBaseURL: true))
        let items = try #require(comps.queryItems)
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.name == "a" })
        #expect(Set(items.compactMap { $0.value }) == ["1", "2"])
    }

    @Test func removingQueryItemsCanRemoveOneOfDuplicates() throws {
        // Remove only the "a" whose value is "2"; the "a=1" remains.
        let u = Self.url("https://example.com/path?a=1&a=2")
        let result = u.removingQueryItems { $0.value == "2" }
        #expect(result.queryDictionary == ["a": "1"])
    }

    // MARK: - removingQueryItems(where:): rethrows

    @Test func removingQueryItemsRethrowsErrorFromPredicate() {
        let u = Self.url("https://example.com/path?a=1&b=2")
        #expect(throws: SampleError.boom) {
            _ = try u.removingQueryItems { item in
                if item.name == "b" { throw SampleError.boom }
                return false
            }
        }
    }

    @Test func removingQueryItemsNonThrowingClosureDoesNotRequireTry() {
        // The rethrows variant must be callable without `try` for a non-throwing closure.
        let u = Self.url("https://example.com/path?a=1")
        let result = u.removingQueryItems { $0.name == "nope" }
        #expect(result.queryDictionary == ["a": "1"])
    }

    @Test func removingQueryItemsThrowsBeforeReachingMatch() {
        // Predicate throws on the very first item; nothing returned.
        let u = Self.url("https://example.com/path?first=1&second=2")
        #expect(throws: SampleError.boom) {
            _ = try u.removingQueryItems { _ in throw SampleError.boom }
        }
    }

    // MARK: - removingQueryItems: percent encoding preserved

    @Test func removingQueryItemsPreservesEncodedValues() throws {
        let u = Self.url("https://example.com/path?name=John%20Doe&drop=x")
        let result = u.removingQueryItems { $0.name == "drop" }
        #expect(result.queryDictionary == ["name": "John Doe"])
        // The reconstructed URL must keep the value percent-encoded.
        #expect(result.absoluteString.contains("John%20Doe"))
    }

    // MARK: - removingAllQueryItems

    @Test func removingAllQueryItemsClearsQuery() {
        let u = Self.url("https://example.com/path?a=1&b=2&c=3")
        let result = u.removingAllQueryItems()
        #expect(result.query == nil)
        #expect(result.queryDictionary.isEmpty)
        #expect(result.absoluteString == "https://example.com/path")
    }

    @Test func removingAllQueryItemsOnURLWithoutQueryIsNoOp() {
        let u = Self.url("https://example.com/path")
        let result = u.removingAllQueryItems()
        #expect(result.absoluteString == "https://example.com/path")
        #expect(result.query == nil)
    }

    @Test func removingAllQueryItemsPreservesFragment() {
        let u = Self.url("https://example.com/path?a=1#frag")
        let result = u.removingAllQueryItems()
        #expect(result.query == nil)
        #expect(result.fragment == "frag")
        #expect(result.absoluteString == "https://example.com/path#frag")
    }

    @Test func removingAllQueryItemsPreservesPort() {
        let u = Self.url("https://example.com:8443/path?a=1")
        let result = u.removingAllQueryItems()
        #expect(result.port == 8443)
        #expect(result.query == nil)
        #expect(result.host == "example.com")
    }

    @Test func removingAllQueryItemsPreservesUserInfo() {
        let u = Self.url("https://user:pass@example.com/path?a=1")
        let result = u.removingAllQueryItems()
        #expect(result.query == nil)
        #expect(result.user == "user")
        #expect(result.password == "pass")
    }

    @Test func removingAllQueryItemsOnFileURL() {
        let u = URL(fileURLWithPath: "/tmp/x/y.txt")
        let result = u.removingAllQueryItems()
        // No query to begin with; path preserved.
        #expect(result.query == nil)
        #expect(result.path == "/tmp/x/y.txt")
    }

    // MARK: - Round-trip / idempotence

    @Test func removingAllQueryItemsIsIdempotent() {
        let u = Self.url("https://example.com/path?a=1&b=2")
        let once = u.removingAllQueryItems()
        let twice = once.removingAllQueryItems()
        #expect(once == twice)
        #expect(twice.query == nil)
    }

    @Test func removingQueryItemsThenAllEqualsAll() {
        let u = Self.url("https://example.com/path?a=1&b=2&c=3")
        let viaPredicate = u.removingQueryItems { _ in true }
        let viaAll = u.removingAllQueryItems()
        #expect(viaPredicate == viaAll)
    }

    @Test func removingThenReadingQueryDictionaryRoundTrip() throws {
        let u = Self.url("https://example.com/path?keep=1&drop=2")
        let result = u.removingQueryItems { $0.name == "drop" }
        // set -> get round trip via queryDictionary
        #expect(result.queryDictionary == ["keep": "1"])
    }

    // MARK: - Large data for removal

    @Test func removingQueryItemsLargeFiltersEvens() throws {
        let count = 10_000
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "example.com"
        comps.path = "/big"
        comps.queryItems = (0..<count).map { URLQueryItem(name: "k\($0)", value: "\($0)") }
        let u = try #require(comps.url)

        // Remove every item whose numeric value is even -> keep only odds.
        let result = u.removingQueryItems { item in
            guard let v = item.value, let n = Int(v) else { return false }
            return n % 2 == 0
        }
        let dict = result.queryDictionary
        #expect(dict.count == count / 2)
        #expect(dict["k1"] == "1")
        #expect(dict["k0"] == nil)
    }
}
