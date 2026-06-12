//
//  StringToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/String+Tools.swift
//  Covers the public `StringProtocol` extensions:
//    - func isValidRange<T: RangeExpression<Index>>(_:) -> Bool
//    - func isValidRange(_ nsRange: NSRange) -> Bool
//    - func range(from nsRange: NSRange) -> Range<Index>?
//    - func nsRange<T: RangeExpression<Index>>(from range: T) -> NSRange?
//    - func ranges<T>(of:options:locale:) -> [Range<Index>]
//    - var utf8Data: Data
//    - var guessedLanguageDirection: Locale.LanguageDirection
//
//  Note: `NSRange.isValid` (from NSRange+Tools.swift) is exercised indirectly
//  through `isValidRange(_:)` / `range(from:)`.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct StringToolsTests {

    // MARK: - Helpers

    /// Builds a `Range<String.Index>` from integer character offsets into `s`.
    private static func charRange(_ s: String, _ lower: Int, _ upper: Int) -> Range<String.Index> {
        let l = s.index(s.startIndex, offsetBy: lower)
        let u = s.index(s.startIndex, offsetBy: upper)
        return l ..< u
    }

    private static func charIndex(_ s: String, _ offset: Int) -> String.Index {
        s.index(s.startIndex, offsetBy: offset)
    }

    // MARK: - isValidRange(RangeExpression) : Range<Index>

    @Test func isValidRange_fullRange_isValid() {
        let s = "hello"
        let r = s.startIndex ..< s.endIndex
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_emptyStringFullRange_isValid() {
        // startIndex == endIndex; empty Range[start..<start] has lower>=start, upper<=end.
        let s = ""
        let r = s.startIndex ..< s.endIndex
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_emptyRangeInMiddle_isValid() {
        let s = "hello"
        let r = Self.charRange(s, 2, 2) // empty range, still in bounds
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_rangeUpToEndIndex_isValid() {
        // Range allows upperBound == endIndex (uses <=).
        let s = "abcd"
        let r = Self.charRange(s, 1, 4)
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_rangeFromStartIndex_isValid() {
        let s = "abcd"
        let r = Self.charRange(s, 0, 2)
        #expect(s.isValidRange(r))
    }

    // MARK: - isValidRange(RangeExpression) : ClosedRange<Index>

    @Test func isValidRange_closedRangeWithinBounds_isValid() {
        // ClosedRange requires upperBound < endIndex.
        let s = "abcde"
        let r = Self.charIndex(s, 1) ... Self.charIndex(s, 3) // up to 'd', index 3 < 5
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_closedRangeUpToLastCharIndex_isValid() {
        // Last valid char index is endIndex-1 == 4; 4 < 5 so valid.
        let s = "abcde"
        let r = Self.charIndex(s, 0) ... Self.charIndex(s, 4)
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_closedRangeUpperBoundEqualsEndIndex_isInvalid() {
        // ClosedRange uses strict `<`, so upperBound == endIndex is invalid.
        // We cannot literally form `... endIndex` meaningfully on a non-empty
        // string without it pointing at endIndex; build it explicitly.
        let s = "abc"
        let r = s.startIndex ... s.endIndex
        #expect(!s.isValidRange(r))
    }

    @Test func isValidRange_closedRangeSingleElement_isValid() {
        let s = "xyz"
        let i = Self.charIndex(s, 1)
        let r = i ... i
        #expect(s.isValidRange(r))
    }

    // MARK: - isValidRange(RangeExpression) : Partial ranges

    @Test func isValidRange_partialFromStart_isValid() {
        let s = "abcd"
        let r: PartialRangeFrom<String.Index> = Self.charIndex(s, 1)...
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialFromStartIndex_isValid() {
        let s = "abcd"
        let r: PartialRangeFrom<String.Index> = s.startIndex...
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialFromEndIndex_isValid() {
        // lowerBound == endIndex still satisfies lowerBound >= startIndex.
        let s = "abcd"
        let r: PartialRangeFrom<String.Index> = s.endIndex...
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialUpToEndIndex_isValid() {
        // PartialRangeUpTo uses upperBound <= endIndex.
        let s = "abcd"
        let r: PartialRangeUpTo<String.Index> = ..<s.endIndex
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialUpToStartIndex_isValid() {
        let s = "abcd"
        let r: PartialRangeUpTo<String.Index> = ..<s.startIndex
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialThroughWithinBounds_isValid() {
        // PartialRangeThrough uses strict upperBound < endIndex.
        let s = "abcd"
        let r: PartialRangeThrough<String.Index> = ...Self.charIndex(s, 2)
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialThroughLastCharIndex_isValid() {
        let s = "abcd"
        let r: PartialRangeThrough<String.Index> = ...Self.charIndex(s, 3) // index 3 < 4
        #expect(s.isValidRange(r))
    }

    @Test func isValidRange_partialThroughEndIndex_isInvalid() {
        // upperBound == endIndex fails the strict `<`.
        let s = "abcd"
        let r: PartialRangeThrough<String.Index> = ...s.endIndex
        #expect(!s.isValidRange(r))
    }

    // MARK: - isValidRange(NSRange)

    @Test func isValidRangeNSRange_validRange_isTrue() {
        let s = "hello world"
        #expect(s.isValidRange(NSRange(location: 0, length: 5)))
    }

    @Test func isValidRangeNSRange_fullLength_isTrue() {
        let s = "hello"
        #expect(s.isValidRange(NSRange(location: 0, length: 5)))
    }

    @Test func isValidRangeNSRange_zeroLengthInBounds_isTrue() {
        let s = "hello"
        #expect(s.isValidRange(NSRange(location: 2, length: 0)))
    }

    @Test func isValidRangeNSRange_lengthBeyondString_isFalse() {
        let s = "hello"
        #expect(!s.isValidRange(NSRange(location: 0, length: 6)))
    }

    @Test func isValidRangeNSRange_locationBeyondString_isFalse() {
        let s = "hello"
        #expect(!s.isValidRange(NSRange(location: 6, length: 0)))
    }

    @Test func isValidRangeNSRange_negativeLocation_isFalse() {
        // NSRange.isValid rejects negative location -> range(from:) returns nil.
        let s = "hello"
        #expect(!s.isValidRange(NSRange(location: -1, length: 1)))
    }

    @Test func isValidRangeNSRange_notFoundLocation_isFalse() {
        let s = "hello"
        #expect(!s.isValidRange(NSRange(location: NSNotFound, length: 0)))
    }

    @Test func isValidRangeNSRange_locationEqualsLengthZeroLen_isTrue() {
        // NSRange at the very end (location == utf16 count, length 0) maps to endIndex.
        let s = "hello"
        #expect(s.isValidRange(NSRange(location: 5, length: 0)))
    }

    @Test func isValidRangeNSRange_emptyString_zeroRange_isTrue() {
        let s = ""
        #expect(s.isValidRange(NSRange(location: 0, length: 0)))
    }

    @Test func isValidRangeNSRange_emptyString_nonZeroLength_isFalse() {
        let s = ""
        #expect(!s.isValidRange(NSRange(location: 0, length: 1)))
    }

    // MARK: - range(from: NSRange)

    @Test func rangeFromNSRange_valid_returnsCorrectSubstring() throws {
        let s = "hello world"
        let r = try #require(s.range(from: NSRange(location: 6, length: 5)))
        #expect(String(s[r]) == "world")
    }

    @Test func rangeFromNSRange_zeroLength_returnsEmptyRange() throws {
        let s = "hello"
        let r = try #require(s.range(from: NSRange(location: 2, length: 0)))
        #expect(r.isEmpty)
        #expect(r.lowerBound == Self.charIndex(s, 2))
    }

    @Test func rangeFromNSRange_invalidNSRange_returnsNil() {
        let s = "hello"
        #expect(s.range(from: NSRange(location: -1, length: 1)) == nil)
        #expect(s.range(from: NSRange(location: NSNotFound, length: 0)) == nil)
    }

    @Test func rangeFromNSRange_outOfBounds_returnsNil() {
        // Range(nsRange, in:) returns nil when the NSRange exceeds the string.
        let s = "hi"
        #expect(s.range(from: NSRange(location: 0, length: 99)) == nil)
    }

    @Test func rangeFromNSRange_roundTripWithNSString() throws {
        // The NSRange should index the same characters NSString would.
        let s = "abcdef"
        let nsRange = NSRange(location: 1, length: 3)
        let r = try #require(s.range(from: nsRange))
        #expect(String(s[r]) == (s as NSString).substring(with: nsRange))
    }

    // MARK: - nsRange(from: range)

    @Test func nsRangeFromRange_valid_returnsCorrectNSRange() throws {
        let s = "hello world"
        let r = Self.charRange(s, 6, 11)
        let nsRange = try #require(s.nsRange(from: r))
        #expect(nsRange.location == 6)
        #expect(nsRange.length == 5)
    }

    @Test func nsRangeFromRange_emptyRange_returnsZeroLength() throws {
        let s = "hello"
        let r = Self.charRange(s, 3, 3)
        let nsRange = try #require(s.nsRange(from: r))
        #expect(nsRange.location == 3)
        #expect(nsRange.length == 0)
    }

    @Test func nsRangeFromRange_fullRange_matchesUTF16Count() throws {
        let s = "hello"
        let r = s.startIndex ..< s.endIndex
        let nsRange = try #require(s.nsRange(from: r))
        #expect(nsRange.location == 0)
        #expect(nsRange.length == s.utf16.count)
    }

    @Test func nsRangeFromRange_invalidRange_returnsNil() {
        // A ClosedRange whose upperBound == endIndex is rejected by isValidRange.
        let s = "abc"
        let r = s.startIndex ... s.endIndex
        #expect(s.nsRange(from: r) == nil)
    }

    @Test func nsRangeFromRange_partialThroughEndIndex_returnsNil() {
        let s = "abc"
        let r: PartialRangeThrough<String.Index> = ...s.endIndex
        #expect(s.nsRange(from: r) == nil)
    }

    @Test func nsRangeFromRange_emoji_accountsForUTF16Width() throws {
        // "👍" is 2 UTF-16 code units. The character after it starts at UTF-16 offset 2.
        let s = "a👍b"
        let r = Self.charRange(s, 1, 2) // just the emoji
        let nsRange = try #require(s.nsRange(from: r))
        #expect(nsRange.location == 1)
        #expect(nsRange.length == 2)
    }

    // MARK: - Round trip: range <-> NSRange

    @Test(arguments: [
        (0, 5), (6, 11), (0, 11), (3, 3), (5, 5),
    ])
    func roundTrip_rangeToNSRangeToRange(lower: Int, upper: Int) throws {
        let s = "hello world"
        let original = Self.charRange(s, lower, upper)
        let nsRange = try #require(s.nsRange(from: original))
        let back = try #require(s.range(from: nsRange))
        #expect(back == original)
        #expect(String(s[back]) == String(s[original]))
    }

    @Test func roundTrip_nsRangeToRangeToNSRange() throws {
        let s = "café latte" // 'é' is a single UTF-16 unit here (precomposed)
        let nsRange = NSRange(location: 0, length: 4)
        let r = try #require(s.range(from: nsRange))
        let back = try #require(s.nsRange(from: r))
        #expect(back == nsRange)
    }

    // MARK: - ranges(of:)

    @Test func ranges_noMatch_returnsEmpty() {
        let s = "hello"
        #expect(s.ranges(of: "z").isEmpty)
    }

    @Test func ranges_singleMatch() {
        let s = "hello"
        let result = s.ranges(of: "ell")
        #expect(result.count == 1)
        #expect(result.map { String(s[$0]) } == ["ell"])
    }

    @Test func ranges_multipleNonOverlappingMatches() {
        let s = "abcabcabc"
        let result = s.ranges(of: "abc")
        #expect(result.count == 3)
        #expect(result.allSatisfy { String(s[$0]) == "abc" })
    }

    @Test func ranges_overlappingPatternAdvancesByUpperBound() {
        // "aa" in "aaaa": matches at 0..<2, 2..<4 (non-overlapping by design).
        let s = "aaaa"
        let result = s.ranges(of: "aa")
        #expect(result.count == 2)
    }

    @Test func ranges_emptySearchString_matchesEveryPosition() {
        // Empty search produces an empty range; the loop advances by one index
        // each time, producing one empty range per character position.
        let s = "abc"
        let result = s.ranges(of: "")
        // range(of: "") returns an empty range at the search start for each step,
        // advancing until endIndex.
        #expect(result.allSatisfy { $0.isEmpty })
        #expect(result.count == s.count)
    }

    @Test func ranges_emptySearchInEmptyString_returnsEmpty() {
        // lastUpperBound == startIndex == endIndex so the while loop never runs.
        let s = ""
        #expect(s.ranges(of: "").isEmpty)
    }

    @Test func ranges_caseInsensitiveOption() {
        let s = "Hello HELLO hello"
        let result = s.ranges(of: "hello", options: [.caseInsensitive])
        #expect(result.count == 3)
    }

    @Test func ranges_caseSensitiveByDefault() {
        let s = "Hello HELLO hello"
        let result = s.ranges(of: "hello")
        #expect(result.count == 1)
        #expect(String(s[result[0]]) == "hello")
    }

    @Test func ranges_backwardsOption() {
        // With .backwards the search still finds matches; result is collected.
        let s = "abcabc"
        let result = s.ranges(of: "abc", options: [.backwards])
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { String(s[$0]) == "abc" })
    }

    @Test func ranges_matchAtStringEnd() {
        let s = "xxxabc"
        let result = s.ranges(of: "abc")
        #expect(result.count == 1)
        #expect(result[0].upperBound == s.endIndex)
    }

    @Test func ranges_unicodeAndEmoji() {
        let s = "🎉party🎉time🎉"
        let result = s.ranges(of: "🎉")
        #expect(result.count == 3)
        #expect(result.allSatisfy { String(s[$0]) == "🎉" })
    }

    @Test func ranges_substringRespectsGraphemeClusters() {
        let s = "naïve naïve"
        let result = s.ranges(of: "naïve")
        #expect(result.count == 2)
    }

    @Test func ranges_searchStringLongerThanSource_returnsEmpty() {
        let s = "ab"
        #expect(s.ranges(of: "abcdef").isEmpty)
    }

    @Test func ranges_largeRepetitiveInput_isBounded() {
        // 100_000 occurrences of "ab"; ensure correctness and that it terminates quickly.
        let s = String(repeating: "ab", count: 100_000)
        let result = s.ranges(of: "ab")
        #expect(result.count == 100_000)
    }

    @Test func ranges_onSubstringType() {
        // StringProtocol conformance: exercise on a Substring slice.
        let full = "xxabcabcxx"
        let sub = full.dropFirst(2).dropLast(2) // "abcabc" as Substring
        let result = sub.ranges(of: "abc")
        #expect(result.count == 2)
        #expect(result.allSatisfy { String(sub[$0]) == "abc" })
    }

    // MARK: - utf8Data

    @Test func utf8Data_ascii() {
        let s = "Hello"
        #expect(s.utf8Data == Data([0x48, 0x65, 0x6C, 0x6C, 0x6F]))
    }

    @Test func utf8Data_empty() {
        let s = ""
        #expect(s.utf8Data == Data())
        #expect(s.utf8Data.isEmpty)
    }

    @Test func utf8Data_roundTripThroughString() throws {
        let s = "Hello, 世界! 🌍 café"
        let data = s.utf8Data
        let back = try #require(String(data: data, encoding: .utf8))
        #expect(back == s)
    }

    @Test func utf8Data_matchesDataUTF8() {
        let s = "café 世界 🎉"
        #expect(s.utf8Data == Data(s.utf8))
        #expect(s.utf8Data == s.data(using: .utf8))
    }

    @Test func utf8Data_emojiByteCount() {
        // "🌍" encodes to 4 UTF-8 bytes.
        let s = "🌍"
        #expect(s.utf8Data.count == 4)
    }

    @Test func utf8Data_onSubstring() {
        let full = "abcdef"
        let sub = full.dropFirst(2) // "cdef"
        #expect(sub.utf8Data == Data("cdef".utf8))
    }

    // MARK: - guessedLanguageDirection

    @Test func guessedLanguageDirection_englishIsLeftToRight() {
        // A reasonably long English sentence should be detected as LTR.
        let s = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 6)
        #expect(s.guessedLanguageDirection == .leftToRight)
    }

    @Test func guessedLanguageDirection_arabicIsRightToLeft() {
        // Arabic text; long enough to give the tokenizer a fair chance.
        let arabic = "السلام عليكم ورحمة الله وبركاته. هذا نص عربي طويل لاختبار اتجاه اللغة. "
        let s = String(repeating: arabic, count: 4)
        #expect(s.guessedLanguageDirection == .rightToLeft)
    }

    @Test func guessedLanguageDirection_hebrewIsRightToLeft() {
        let hebrew = "שלום עולם זהו טקסט עברי ארוך לבדיקת כיוון השפה והתצוגה. "
        let s = String(repeating: hebrew, count: 4)
        #expect(s.guessedLanguageDirection == .rightToLeft)
    }

    @Test func guessedLanguageDirection_emptyStringIsUnknown() {
        // No text -> tokenizer cannot guess -> .unknown.
        #expect("".guessedLanguageDirection == .unknown)
    }

    @Test func guessedLanguageDirection_returnsAValidDirectionValue() {
        // Whatever the guess, it must be one of the known enum cases (never crashes).
        let s = "12345 67890 !@#$%"
        let dir = s.guessedLanguageDirection
        let valid: Set<Locale.LanguageDirection> = [
            .leftToRight, .rightToLeft, .topToBottom, .bottomToTop, .unknown,
        ]
        #expect(valid.contains(dir))
    }

    @Test func guessedLanguageDirection_onlyConsidersFirstPrefix() {
        // The implementation only inspects prefix(200); a long English prefix
        // should keep the guess LTR regardless of trailing content.
        let englishPrefix = String(repeating: "The quick brown fox jumps. ", count: 12)
        let s = englishPrefix + "السلام عليكم"
        #expect(s.guessedLanguageDirection == .leftToRight)
    }

    // MARK: - Concurrency: value-type extensions are pure; hammer them in parallel

    @Test func concurrent_utf8Data_isConsistent() async {
        let s = "Concurrency 测试 🎯 café"
        let expected = s.utf8Data
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 500 {
                group.addTask { s.utf8Data == expected }
            }
            var allMatch = true
            for await ok in group where !ok { allMatch = false }
            #expect(allMatch)
        }
    }

    @Test func concurrent_ranges_isConsistent() async {
        let s = String(repeating: "abXY", count: 1000)
        let expected = s.ranges(of: "XY").count
        #expect(expected == 1000)
        await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 200 {
                group.addTask { s.ranges(of: "XY").count }
            }
            var allMatch = true
            for await count in group where count != expected { allMatch = false }
            #expect(allMatch)
        }
    }

    @Test func concurrent_rangeConversions_areConsistent() async {
        let s = "the quick brown fox jumps over the lazy dog"
        await withTaskGroup(of: Bool.self) { group in
            for offset in 0 ..< 200 {
                group.addTask {
                    let lower = offset % (s.count - 1)
                    let r = Self.charRange(s, lower, lower + 1)
                    guard let ns = s.nsRange(from: r),
                          let back = s.range(from: ns) else { return false }
                    return back == r
                }
            }
            var allOK = true
            for await ok in group where !ok { allOK = false }
            #expect(allOK)
        }
    }
}
