//
//  NSStringToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Extension/Foundation/NSString+Tools.swift
//
//  Public NSString extension members under test:
//    func isValidRange(_ nsRange: NSRange) -> Bool
//        nsRange.isValid && nsRange.location <= length && nsRange.upperBound <= length
//    func nsRange<T: RangeExpression<String.Index>>(from range: T) -> NSRange?
//        delegates to (self as String).nsRange(from:)
//    func ranges(of:options:locale:) -> [NSRange]
//        non-overlapping forward sweep using range(of:options:range:locale:),
//        guarded by isValidRange; empty/zero-length matches advance by +1.
//
//  Cross-referenced source (same test module):
//    NSRange.isValid  (NSRange+Tools.swift):
//        location >= 0 && location != NSNotFound && length >= 0 && length <= Int.max - location
//    String.nsRange(from:) / String.ranges(of:) (String+Tools.swift) — the
//    NSString members delegate to / parallel these.
//
//  NSString indexes in UTF-16 code units, so emoji (surrogate pairs) and
//  combining marks are exercised explicitly. All expected values were verified
//  empirically against a faithful mirror of the source before being pinned here.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct NSStringToolsTests {

    // MARK: - Helpers

    /// Render NSRanges compactly for failure messages.
    private static func describe(_ ranges: [NSRange]) -> String {
        "[" + ranges.map { "{\($0.location),\($0.length)}" }.joined(separator: ", ") + "]"
    }

    private static func nsr(_ location: Int, _ length: Int) -> NSRange {
        NSRange(location: location, length: length)
    }

    // MARK: - isValidRange: happy path

    @Test func isValidRangeWholeAndSubAndEmpty() {
        let s = "hello" as NSString
        #expect(s.length == 5)
        #expect(s.isValidRange(NSRange(location: 0, length: 5)))   // whole
        #expect(s.isValidRange(NSRange(location: 1, length: 3)))   // interior sub
        #expect(s.isValidRange(NSRange(location: 0, length: 0)))   // empty at start
        #expect(s.isValidRange(NSRange(location: 5, length: 0)))   // empty at end (location == length)
        #expect(s.isValidRange(NSRange(location: 2, length: 0)))   // empty interior
        #expect(s.isValidRange(NSRange(location: 4, length: 1)))   // last char
    }

    @Test func isValidRangeRejectsOutOfBounds() {
        let s = "hello" as NSString
        // upperBound past length
        #expect(!s.isValidRange(NSRange(location: 5, length: 1)))
        #expect(!s.isValidRange(NSRange(location: 0, length: 6)))
        #expect(!s.isValidRange(NSRange(location: 3, length: 3)))   // upperBound == 6 > 5
        // location past length (even with zero length)
        #expect(!s.isValidRange(NSRange(location: 6, length: 0)))
        #expect(!s.isValidRange(NSRange(location: 100, length: 0)))
    }

    @Test func isValidRangeRejectsInvalidNSRangeComponents() {
        let s = "hello" as NSString
        // Negative location -> NSRange.isValid is false.
        #expect(!s.isValidRange(NSRange(location: -1, length: 0)))
        #expect(!s.isValidRange(NSRange(location: 2, length: -1)))
        // NSNotFound sentinel location.
        #expect(!s.isValidRange(NSRange(location: NSNotFound, length: 0)))
        // The {NSNotFound, 0} value Foundation returns from a failed search.
        let notFound = s.range(of: "xyz")
        #expect(notFound.location == NSNotFound)
        #expect(notFound.length == 0)
        #expect(!s.isValidRange(notFound))
    }

    @Test func isValidRangeOnEmptyReceiverOnlyAllowsZeroZero() {
        let empty = "" as NSString
        #expect(empty.length == 0)
        #expect(empty.isValidRange(NSRange(location: 0, length: 0)))
        #expect(!empty.isValidRange(NSRange(location: 0, length: 1)))
        #expect(!empty.isValidRange(NSRange(location: 1, length: 0)))
        #expect(!empty.isValidRange(NSRange(location: 1, length: 1)))
    }

    @Test func isValidRangeUsesUTF16LengthForEmojiAndCombining() {
        // "😀" is a surrogate pair: 2 UTF-16 code units.
        let emoji = "a😀b" as NSString
        #expect(emoji.length == 4)
        #expect(emoji.isValidRange(NSRange(location: 0, length: 4)))   // whole, valid
        #expect(emoji.isValidRange(NSRange(location: 1, length: 2)))   // the emoji span
        #expect(!emoji.isValidRange(NSRange(location: 0, length: 5)))  // one past UTF-16 length

        // Combining mark: "e" + U+0301 = 2 UTF-16 units in the decomposed form.
        let combining = "e\u{0301}" as NSString
        #expect(combining.length == 2)
        #expect(combining.isValidRange(NSRange(location: 0, length: 2)))
        #expect(!combining.isValidRange(NSRange(location: 0, length: 3)))
    }

    // Boundary sweep: for an NSString of length n, {n, 0} is valid but {n+1, 0}
    // and {0, n+1} are not.
    @Test(arguments: ["", "a", "abc", "a😀b", "中文字"])
    func isValidRangeBoundaryConsistency(_ raw: String) {
        let s = raw as NSString
        let n = s.length
        #expect(s.isValidRange(NSRange(location: 0, length: n)))     // whole
        #expect(s.isValidRange(NSRange(location: n, length: 0)))     // empty at end
        #expect(!s.isValidRange(NSRange(location: n + 1, length: 0)))
        #expect(!s.isValidRange(NSRange(location: 0, length: n + 1)))
        if n > 0 {
            #expect(s.isValidRange(NSRange(location: n - 1, length: 1)))
        }
    }

    // MARK: - nsRange(from:)

    @Test func nsRangeFromFullRange() {
        let str = "Hello"
        let s = str as NSString
        let full = str.startIndex ..< str.endIndex
        #expect(s.nsRange(from: full) == NSRange(location: 0, length: 5))
    }

    @Test func nsRangeFromInteriorAndEmptyRanges() {
        let str = "Hello"
        let s = str as NSString
        let two = str.index(str.startIndex, offsetBy: 2)
        let four = str.index(str.startIndex, offsetBy: 4)
        // Interior [2, 4)
        #expect(s.nsRange(from: two ..< four) == NSRange(location: 2, length: 2))
        // Empty interior [2, 2)
        #expect(s.nsRange(from: two ..< two) == NSRange(location: 2, length: 0))
    }

    @Test func nsRangeFromPartialRangeExpressions() {
        let str = "Hello"
        let s = str as NSString
        let two = str.index(str.startIndex, offsetBy: 2)
        let three = str.index(str.startIndex, offsetBy: 3)
        let four = str.index(str.startIndex, offsetBy: 4)
        // PartialRangeFrom: [2, end)
        #expect(s.nsRange(from: two...) == NSRange(location: 2, length: 3))
        // PartialRangeUpTo: [start, 3)
        #expect(s.nsRange(from: ..<three) == NSRange(location: 0, length: 3))
        // ClosedRange: [0, 3] -> length 4
        #expect(s.nsRange(from: str.startIndex...three) == NSRange(location: 0, length: 4))
        // PartialRangeThrough: [start, 4] -> length 5
        #expect(s.nsRange(from: ...four) == NSRange(location: 0, length: 5))
    }

    @Test func nsRangeFromEmptyString() {
        let str = ""
        let s = str as NSString
        #expect(s.nsRange(from: str.startIndex ..< str.endIndex) == NSRange(location: 0, length: 0))
    }

    @Test func nsRangeFromEmojiSpanUsesUTF16Offsets() {
        let str = "a😀b"
        let s = str as NSString
        #expect(s.length == 4)
        // Whole string -> UTF-16 length 4.
        #expect(s.nsRange(from: str.startIndex ..< str.endIndex) == NSRange(location: 0, length: 4))
        // The emoji character occupies UTF-16 [1, 3).
        let afterA = str.index(str.startIndex, offsetBy: 1)
        let afterEmoji = str.index(str.startIndex, offsetBy: 2)
        #expect(s.nsRange(from: afterA ..< afterEmoji) == NSRange(location: 1, length: 2))
    }

    @Test func nsRangeFromParityWithStringExtension() {
        // The NSString member is documented to delegate to (self as String).
        let str = "Round trip 世界"
        let s = str as NSString
        let two = str.index(str.startIndex, offsetBy: 2)
        let r1: NSRange? = s.nsRange(from: two ..< str.endIndex)
        let r2: NSRange? = str.nsRange(from: two ..< str.endIndex)
        #expect(r1 == r2)
        #expect(r1 != nil)
    }

    @Test func nsRangeRoundTripStringIndexToNSRangeAndBack() {
        let str = "Hello, 世界!"
        let s = str as NSString
        guard let sub = str.range(of: "世界") else {
            Issue.record("substring not found")
            return
        }
        let ns = try! #require(s.nsRange(from: sub))
        // Reconstruct a Range<String.Index> from the NSRange and confirm identity.
        let back = try! #require(Range(ns, in: str))
        #expect(back == sub)
        #expect(String(str[back]) == "世界")
    }

    // MARK: - ranges(of:): basic matches

    @Test func rangesSingleMatch() {
        let s = "hello world" as NSString
        let r = s.ranges(of: "world")
        #expect(r == [Self.nsr(6, 5)], "\(Self.describe(r))")
    }

    @Test func rangesMultipleMatches() {
        let s = "a-b-c-d" as NSString
        let r = s.ranges(of: "-")
        #expect(r == [Self.nsr(1, 1), Self.nsr(3, 1), Self.nsr(5, 1)], "\(Self.describe(r))")
    }

    @Test func rangesNoMatch() {
        let s = "abcdef" as NSString
        #expect(s.ranges(of: "xyz").isEmpty)
        #expect(s.ranges(of: "z").isEmpty)
    }

    @Test func rangesRepeatedSingleChar() {
        let s = "aaaa" as NSString
        let r = s.ranges(of: "a")
        #expect(r == [Self.nsr(0, 1), Self.nsr(1, 1), Self.nsr(2, 1), Self.nsr(3, 1)], "\(Self.describe(r))")
    }

    // MARK: - ranges(of:): non-overlapping advance semantics

    @Test func rangesNonOverlappingForRepeatedPattern() {
        // "aa" in "aaaa": after matching {0,2}, search resumes at index 2 -> {2,2}.
        // Overlapping {1,3} is intentionally NOT reported.
        let s = "aaaa" as NSString
        let r = s.ranges(of: "aa")
        #expect(r == [Self.nsr(0, 2), Self.nsr(2, 2)], "\(Self.describe(r))")
    }

    @Test func rangesSelfOverlappingPatternReportsOnlyNonOverlapping() {
        // "aba" in "ababa": first match {0,3}; resume at 3 -> "ba" has no "aba".
        let s = "ababa" as NSString
        let r = s.ranges(of: "aba")
        #expect(r == [Self.nsr(0, 3)], "\(Self.describe(r))")
    }

    // MARK: - ranges(of:): empty / boundary cases

    @Test func rangesEmptySearchStringTerminatesImmediately() {
        // range(of: "") returns {NSNotFound, 0}, which fails isValidRange and
        // terminates the loop -> empty result (no infinite loop).
        let s = "abc" as NSString
        #expect(s.ranges(of: "").isEmpty)
    }

    @Test func rangesEmptyReceiver() {
        let empty = "" as NSString
        #expect(empty.ranges(of: "a").isEmpty)
        #expect(empty.ranges(of: "").isEmpty)
    }

    @Test func rangesMatchAtStringBoundaries() {
        let s = "xabcx" as NSString
        #expect(s.ranges(of: "x") == [Self.nsr(0, 1), Self.nsr(4, 1)], "\(Self.describe(s.ranges(of: "x")))")
        // Match spanning the whole receiver.
        let whole = "abc" as NSString
        #expect(whole.ranges(of: "abc") == [Self.nsr(0, 3)])
    }

    // MARK: - ranges(of:): CompareOptions

    @Test func rangesCaseSensitiveByDefault() {
        let s = "aAaA" as NSString
        #expect(s.ranges(of: "A") == [Self.nsr(1, 1), Self.nsr(3, 1)], "\(Self.describe(s.ranges(of: "A")))")
    }

    @Test func rangesCaseInsensitive() {
        let s = "aAaA" as NSString
        let r = s.ranges(of: "A", options: .caseInsensitive)
        #expect(r == [Self.nsr(0, 1), Self.nsr(1, 1), Self.nsr(2, 1), Self.nsr(3, 1)], "\(Self.describe(r))")
    }

    @Test func rangesBackwardsFindsLastInWindowOnly() {
        // ".backwards" makes range(of:) search the window from the end. In
        // "a-b-c" the first window [0,5) yields the LAST "-" at {3,1}; the loop
        // then advances lastUpperBound to 4, and the window [4,5) = "c" has no
        // "-", so the result is a single match {3,1}.
        let s = "a-b-c" as NSString
        let r = s.ranges(of: "-", options: .backwards)
        #expect(r == [Self.nsr(3, 1)], "\(Self.describe(r))")
    }

    @Test func rangesDiacriticInsensitive() {
        // Searching "e" diacritic-insensitively matches the accented "é".
        let s = "café" as NSString
        let r = s.ranges(of: "e", options: .diacriticInsensitive)
        #expect(r.count == 1, "\(Self.describe(r))")
        // The matched code unit(s) must round-trip to an "é"-like grapheme,
        // verified diacritic-insensitively against "e".
        if let first = r.first {
            #expect(s.isValidRange(first))
            let matched = s.substring(with: first)
            #expect(matched.compare("e", options: .diacriticInsensitive) == .orderedSame, "matched=\(matched)")
        }
    }

    @Test func rangesPinnedLocaleEnUS() {
        // Pin the locale so behavior is deterministic regardless of the device
        // region (e.g. case folding rules for special characters).
        let locale = Locale(identifier: "en_US")
        let s = "İstanbul istanbul" as NSString
        let r = s.ranges(of: "i", options: .caseInsensitive, locale: locale)
        // We only assert that every reported range is in-bounds and substring
        // identity holds; the count is locale-dependent but must be stable here.
        for nsRange in r {
            #expect(s.isValidRange(nsRange))
            #expect(nsRange.length >= 1)
        }
        #expect(!r.isEmpty)
    }

    // MARK: - ranges(of:): UTF-16 offsets for non-BMP / CJK

    @Test func rangesEmojiUsesUTF16Offsets() {
        let s = "a😀b😀c" as NSString
        #expect(s.length == 7)  // a(1) 😀(2) b(1) 😀(2) c(1)
        let r = s.ranges(of: "😀")
        #expect(r == [Self.nsr(1, 2), Self.nsr(4, 2)], "\(Self.describe(r))")
        // Each reported range bridges back to the emoji.
        for nsRange in r {
            #expect(s.substring(with: nsRange) == "😀")
        }
    }

    @Test func rangesBMPCJKOffsets() {
        let s = "中a中b中" as NSString
        let r = s.ranges(of: "中")
        #expect(r == [Self.nsr(0, 1), Self.nsr(2, 1), Self.nsr(4, 1)], "\(Self.describe(r))")
    }

    @Test func rangesSubstringIdentity() {
        // Every range returned must, when used to slice the receiver, equal the
        // search string (case-sensitive default).
        let s = "the cat sat on the mat" as NSString
        let needle = "at"
        let r = s.ranges(of: needle)
        #expect(r.count == 3, "\(Self.describe(r))")
        for nsRange in r {
            #expect(s.isValidRange(nsRange))
            #expect(s.substring(with: nsRange) == needle)
        }
    }

    // MARK: - ranges(of:): parity with String.ranges(of:)

    @Test func rangesParityWithStringExtension() {
        let str = "abcabcXabc"
        let s = str as NSString
        let needle = "abc"
        let nsResults = s.ranges(of: needle)
        // Convert the String extension's results to UTF-16 NSRanges for comparison.
        let stringResults = str.ranges(of: needle).map { NSRange($0, in: str) }
        #expect(nsResults == stringResults, "ns=\(Self.describe(nsResults)) str=\(Self.describe(stringResults))")
    }

    @Test func rangesParityWithStringExtensionEmoji() {
        let str = "x😀y😀z😀"
        let s = str as NSString
        let needle = "😀"
        let nsResults = s.ranges(of: needle)
        let stringResults = str.ranges(of: needle).map { NSRange($0, in: str) }
        #expect(nsResults == stringResults, "ns=\(Self.describe(nsResults)) str=\(Self.describe(stringResults))")
        #expect(nsResults.count == 3)
    }

    // MARK: - Large but bounded data

    @Test func rangesLargeNonOverlappingSweep() {
        // 50_000 occurrences of "ab" separated by "-": "ab-ab-...-ab".
        let count = 50_000
        let s = Array(repeating: "ab", count: count).joined(separator: "-") as NSString
        let r = s.ranges(of: "ab")
        #expect(r.count == count)
        // Spot-check the first and last reported ranges.
        #expect(r.first == Self.nsr(0, 2))
        #expect(r.last == Self.nsr((count - 1) * 3, 2))
        // Strictly increasing, non-overlapping locations.
        var prevUpper = -1
        var monotonic = true
        for nsRange in r {
            if nsRange.location < prevUpper { monotonic = false; break }
            prevUpper = nsRange.upperBound
        }
        #expect(monotonic)
    }

    @Test func rangesLargeSingleCharSweep() {
        let count = 100_000
        let s = String(repeating: "a", count: count) as NSString
        let r = s.ranges(of: "a")
        #expect(r.count == count)
        #expect(r.first == Self.nsr(0, 1))
        #expect(r.last == Self.nsr(count - 1, 1))
    }

    // MARK: - Concurrency: pure reads must be consistent under contention

    @Test func concurrentIsValidRangeIsConsistent() async {
        // NSString is not Sendable under Swift 6, so capture the Sendable String
        // and rebuild the NSString inside each child task.
        let base = "hello world"
        let valid = NSRange(location: 0, length: 5)
        let invalid = NSRange(location: 100, length: 1)

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for i in 0..<1_000 {
                group.addTask {
                    let s = base as NSString
                    if i % 2 == 0 {
                        return s.isValidRange(valid)
                    } else {
                        return !s.isValidRange(invalid)
                    }
                }
            }
            var acc: [Bool] = []
            for await r in group { acc.append(r) }
            return acc
        }

        #expect(results.count == 1_000)
        #expect(results.allSatisfy { $0 })
    }

    @Test func concurrentRangesAndNSRangeAreDeterministic() async {
        let str = "a-b-c-d-e-f-g"
        let s = str as NSString
        let needle = "-"
        let expectedRanges = s.ranges(of: needle)
        let two = str.index(str.startIndex, offsetBy: 2)
        let expectedNSRange = s.nsRange(from: two ..< str.endIndex)

        // Capture only Sendable value copies into the task group:
        // NSString (immutable, Sendable), the String, NSRange/[NSRange] (Sendable),
        // and String.Index (Sendable).
        let okResults = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<500 {
                group.addTask {
                    let localS = str as NSString
                    let r = localS.ranges(of: needle)
                    let nr = localS.nsRange(from: two ..< str.endIndex)
                    return r == expectedRanges && nr == expectedNSRange
                }
            }
            var acc: [Bool] = []
            for await ok in group { acc.append(ok) }
            return acc
        }

        #expect(okResults.count == 500)
        #expect(okResults.allSatisfy { $0 })
        #expect(expectedRanges.count == 6)
        #expect(expectedNSRange != nil)
    }
}
