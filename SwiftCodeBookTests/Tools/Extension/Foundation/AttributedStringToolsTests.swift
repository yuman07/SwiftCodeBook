//
//  AttributedStringToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/AttributedString+Tools.swift
//  Covers AttributedStringProtocol.string, .ranges(of:), .split(...) and
//  AttributedString.trimmingWhitespacesAndNewlines().
//
//  Notes on verified behavior (confirmed via standalone swiftc builds against
//  the real source logic on the iOS 26 simulator toolchain):
//   * AttributedSubstring.range(of: "") returns nil, so .ranges(of: "")
//     returns [] (no infinite loop, no per-character matches).
//   * .ranges(of:options:.backwards) finds only the LAST occurrence: after the
//     first iteration lastUpperBound jumps past it (near endIndex), so the loop
//     terminates with a single range.
//   * trimmingWhitespacesAndNewlines() strips the full Unicode \s class
//     (space, tab, newline, CR, vertical tab, form feed, NBSP U+00A0, line
//     separator U+2028, ...) but preserves interior whitespace.
//
//  AttributedString and String.CompareOptions are Sendable value types, so the
//  concurrency stress tests capture them directly with no isolation issues.
//  No sleeps / timing races are used anywhere; every test is deterministic.
//

import Testing
import Foundation
import SwiftUI
@testable import SwiftCodeBook

@Suite struct AttributedStringToolsTests {

    // MARK: - Helpers

    /// Builds an AttributedString from plain text.
    private func make(_ string: String) -> AttributedString {
        AttributedString(string)
    }

    /// Plain-text of every component, in order.
    private func texts(_ subs: [AttributedSubstring]) -> [String] {
        subs.map { String($0.characters[...]) }
    }

    /// Plain-text of a single range within an AttributedString.
    private func text(_ a: AttributedString, _ r: Range<AttributedString.Index>) -> String {
        String(a[r].characters[...])
    }

    // MARK: - .string

    @Test func stringReturnsPlainContent() {
        #expect(make("Hello, World!").string == "Hello, World!")
    }

    @Test func stringOnEmpty() {
        #expect(make("").string == "")
    }

    @Test(arguments: [
        "",
        "a",
        "abc",
        "Hello, World!",
        "  leading and trailing  ",
        "line1\nline2\tcol",
        "café",                 // combining-friendly
        "👨‍👩‍👧‍👦 family",       // multi-scalar grapheme cluster
        "e\u{0301}",            // e + combining acute accent
        "𝕊𝕨𝕚𝕗𝕥",                // astral-plane (surrogate-pair) scalars
        "中文字符串",             // CJK
    ])
    func stringRoundTrips(_ source: String) {
        // String -> AttributedString -> String round trip preserves characters.
        #expect(make(source).string == source)
    }

    @Test func stringReflectsMutation() {
        var a = make("abc")
        a.append(make("def"))
        #expect(a.string == "abcdef")
    }

    @Test func stringCountMatchesCharacterCount() {
        // .string must agree with the underlying grapheme-cluster count, even
        // for multi-scalar clusters.
        let a = make("👨‍👩‍👧‍👦x")
        #expect(a.string == "👨‍👩‍👧‍👦x")
        #expect(a.string.count == 2)
    }

    // MARK: - .ranges(of:)

    @Test func rangesFindsSingleOccurrence() {
        let a = make("hello")
        let ranges = a.ranges(of: "ll")
        #expect(ranges.count == 1)
        #expect(text(a, ranges[0]) == "ll")
    }

    @Test func rangesFindsMultipleNonOverlapping() {
        let a = make("a-b-c-d")
        let ranges = a.ranges(of: "-")
        #expect(ranges.count == 3)
        for r in ranges {
            #expect(text(a, r) == "-")
        }
        // Ranges are strictly increasing and non-overlapping.
        for i in 1 ..< ranges.count {
            #expect(ranges[i - 1].upperBound <= ranges[i].lowerBound)
        }
    }

    @Test func rangesReconstructsAllMatchesInOrder() {
        // Slicing the source at each reported range yields the search token
        // every time, in left-to-right order.
        let a = make("xyzABxyzCDxyz")
        let ranges = a.ranges(of: "xyz")
        #expect(ranges.count == 3)
        #expect(ranges.allSatisfy { text(a, $0) == "xyz" })
        #expect(ranges[0].lowerBound == a.startIndex)
        #expect(ranges.last?.upperBound == a.endIndex)
    }

    @Test func rangesOverlappingCandidatesAreNonOverlapping() {
        // "aaaa" searching "aa": matches at 0..2 and 2..4 (non-overlapping).
        let a = make("aaaa")
        let ranges = a.ranges(of: "aa")
        #expect(ranges.count == 2)
        for r in ranges {
            #expect(text(a, r) == "aa")
        }
        // Second match begins exactly where the first ended (no overlap, no gap).
        #expect(ranges[0].upperBound == ranges[1].lowerBound)
    }

    @Test func rangesOverlappingMultiCharLeavesRemainder() {
        // "aaaaa" / "aa": 0..2, 2..4, then a single trailing 'a' is unmatched.
        let a = make("aaaaa")
        let ranges = a.ranges(of: "aa")
        #expect(ranges.count == 2)
        #expect(ranges.last?.upperBound != a.endIndex)
    }

    @Test func rangesNoMatchReturnsEmpty() {
        let a = make("hello")
        #expect(a.ranges(of: "z").isEmpty)
    }

    @Test func rangesSearchLongerThanSourceReturnsEmpty() {
        let a = make("ab")
        #expect(a.ranges(of: "abc").isEmpty)
    }

    @Test func rangesOnEmptyStringReturnsEmpty() {
        let a = make("")
        #expect(a.ranges(of: "x").isEmpty)
    }

    @Test func rangesEmptySearchStringReturnsEmpty() {
        // Empirically, AttributedSubstring.range(of: "") returns nil rather than
        // an empty range, so the while-loop condition fails immediately and the
        // result is an empty array (no infinite loop, no per-character matches).
        let a = make("abc")
        let ranges = a.ranges(of: "")
        #expect(ranges.isEmpty)
    }

    @Test func rangesEmptySearchOnEmptyStringReturnsEmpty() {
        // startIndex == endIndex, so the while-loop body never executes.
        let a = make("")
        #expect(a.ranges(of: "").isEmpty)
    }

    @Test func rangesCaseInsensitiveOption() {
        let a = make("HeLLo heLLo")
        let sensitive = a.ranges(of: "ll")
        #expect(sensitive.isEmpty)
        let insensitive = a.ranges(of: "ll", options: .caseInsensitive)
        #expect(insensitive.count == 2)
        for r in insensitive {
            // Whatever case the source used, the slice length is 2.
            #expect(text(a, r).count == 2)
        }
    }

    @Test func rangesBackwardsFindsOnlyLastOccurrence() {
        // VERIFIED behavior: with .backwards, range(of:) returns the LAST match
        // of "-" inside [startIndex..<endIndex]; lastUpperBound then jumps past
        // it, so the loop ends after one iteration -> exactly one range, and it
        // is the final separator.
        let a = make("a-b-c-d")
        let ranges = a.ranges(of: "-", options: .backwards)
        #expect(ranges.count == 1)
        #expect(text(a, ranges[0]) == "-")
        // It is the trailing-most "-": only a single char ("d") follows it.
        let tail = String(a[ranges[0].upperBound ..< a.endIndex].characters[...])
        #expect(tail == "d")
    }

    @Test func rangesMatchAtStartAndEnd() {
        let a = make("xabcx")
        let ranges = a.ranges(of: "x")
        #expect(ranges.count == 2)
        // First match sits at the very start; last match touches the very end.
        #expect(ranges[0].lowerBound == a.startIndex)
        #expect(ranges[1].upperBound == a.endIndex)
    }

    @Test func rangesEntireStringIsSingleMatch() {
        let a = make("whole")
        let ranges = a.ranges(of: "whole")
        #expect(ranges.count == 1)
        #expect(ranges[0].lowerBound == a.startIndex)
        #expect(ranges[0].upperBound == a.endIndex)
    }

    @Test func rangesWithUnicodeGrapheme() {
        // Emoji separators inside text.
        let a = make("a😀b😀c")
        let ranges = a.ranges(of: "😀")
        #expect(ranges.count == 2)
        for r in ranges {
            #expect(text(a, r) == "😀")
        }
    }

    @Test func rangesWithLocale() {
        // The locale parameter is forwarded to range(of:options:locale:);
        // for plain ASCII a POSIX locale yields the same matches as nil.
        let a = make("a-b-c")
        let withLocale = a.ranges(of: "-", locale: Locale(identifier: "en_US_POSIX"))
        #expect(withLocale.count == 2)
    }

    @Test func rangesLargeInputBounded() {
        // 100_000 occurrences; must stay fast and count correctly.
        let count = 100_000
        let a = make(String(repeating: "x", count: count))
        let ranges = a.ranges(of: "x")
        #expect(ranges.count == count)
    }

    // MARK: - .split

    @Test func splitBasic() {
        let a = make("a,b,c")
        let parts = texts(a.split(separator: ","))
        #expect(parts == ["a", "b", "c"])
    }

    @Test func splitNoSeparatorReturnsWhole() {
        let a = make("abc")
        let parts = texts(a.split(separator: ","))
        #expect(parts == ["abc"])
    }

    @Test func splitSingleCharNoSeparator() {
        let a = make("a")
        #expect(texts(a.split(separator: ",")) == ["a"])
    }

    @Test func splitOnEmptyStringDefault() {
        // No separators found; with omittingEmptySubsequences the trailing
        // [startIndex..<endIndex] is empty so it is omitted -> [].
        let a = make("")
        let parts = texts(a.split(separator: ","))
        #expect(parts.isEmpty)
    }

    @Test func splitOnEmptyStringNotOmitting() {
        // Without omitting, the single empty whole-string piece survives.
        let a = make("")
        #expect(texts(a.split(separator: ",", omittingEmptySubsequences: false)) == [""])
    }

    @Test func splitOmittingEmptySubsequencesTrue() {
        // Consecutive separators and edge separators produce empty pieces that
        // are dropped when omittingEmptySubsequences == true (default).
        let a = make(",a,,b,")
        let parts = texts(a.split(separator: ","))
        #expect(parts == ["a", "b"])
    }

    @Test func splitOmittingEmptySubsequencesFalse() {
        // Keep all empty pieces: leading, between, and trailing.
        let a = make(",a,,b,")
        let parts = texts(a.split(separator: ",", omittingEmptySubsequences: false))
        #expect(parts == ["", "a", "", "b", ""])
    }

    @Test func splitKeepSeparatorTrue() {
        let a = make("a,b,c")
        let parts = texts(a.split(separator: ",", keepSeparator: true))
        #expect(parts == ["a", ",", "b", ",", "c"])
    }

    @Test func splitKeepSeparatorOmittingDropsEmptyContentNotSeparators() {
        // keepSeparator: true with omitting (default) true. Empty content pieces
        // between adjacent separators are dropped, but every separator is kept.
        let a = make(",a,,b,")
        let parts = texts(a.split(separator: ",", keepSeparator: true))
        #expect(parts == [",", "a", ",", ",", "b", ","])
    }

    @Test func splitKeepSeparatorWithoutOmitting() {
        let a = make("a,,b")
        let parts = texts(a.split(separator: ",", keepSeparator: true, omittingEmptySubsequences: false))
        // "a" , "," , (empty between the two commas) , "," , "b"
        #expect(parts == ["a", ",", "", ",", "b"])
    }

    @Test func splitCaseInsensitive() {
        let a = make("aXbxc")
        let sensitive = texts(a.split(separator: "x"))
        #expect(sensitive == ["aXb", "c"])
        let insensitive = texts(a.split(separator: "x", options: .caseInsensitive))
        #expect(insensitive == ["a", "b", "c"])
    }

    @Test func splitMultiCharSeparator() {
        let a = make("one::two::three")
        let parts = texts(a.split(separator: "::"))
        #expect(parts == ["one", "two", "three"])
    }

    @Test func splitLeadingAndTrailingSeparatorOmitted() {
        let a = make("-mid-")
        let parts = texts(a.split(separator: "-"))
        #expect(parts == ["mid"])
    }

    @Test func splitAllSeparators() {
        let a = make(",,,")
        let omitting = texts(a.split(separator: ","))
        #expect(omitting.isEmpty)
        let keeping = texts(a.split(separator: ",", omittingEmptySubsequences: false))
        #expect(keeping == ["", "", "", ""])
    }

    @Test func splitWholeStringIsSeparator() {
        let a = make("==")
        let omitting = texts(a.split(separator: "=="))
        #expect(omitting.isEmpty)
        let keeping = texts(a.split(separator: "==", omittingEmptySubsequences: false))
        #expect(keeping == ["", ""])
    }

    @Test func splitPreservesContentConcatenation() {
        // Concatenating components + separators should reconstruct the source
        // when keepSeparator is true (and not omitting empties).
        let source = "x,y,,z"
        let a = make(source)
        let parts = texts(a.split(separator: ",", keepSeparator: true, omittingEmptySubsequences: false))
        #expect(parts.joined() == source)
    }

    @Test func splitPreservesContentConcatenationWithEdges() {
        // Round-trip including leading/trailing separators.
        let source = ",a,,b,"
        let a = make(source)
        let parts = texts(a.split(separator: ",", keepSeparator: true, omittingEmptySubsequences: false))
        #expect(parts.joined() == source)
    }

    @Test func splitUnicodeSeparator() {
        let a = make("a🍎b🍎c")
        let parts = texts(a.split(separator: "🍎"))
        #expect(parts == ["a", "b", "c"])
    }

    @Test func splitLargeInputBounded() {
        // Build "x,x,x,...,x" with 50_000 x's separated by commas.
        let n = 50_000
        let source = Array(repeating: "x", count: n).joined(separator: ",")
        let a = make(source)
        let parts = a.split(separator: ",")
        #expect(parts.count == n)
        #expect(String(parts.first!.characters[...]) == "x")
        #expect(String(parts.last!.characters[...]) == "x")
    }

    // MARK: - .trimmingWhitespacesAndNewlines

    @Test(arguments: [
        ("  hello  ", "hello"),
        ("\thello\t", "hello"),
        ("\nhello\n", "hello"),
        ("   leading", "leading"),
        ("trailing   ", "trailing"),
        ("\n\t  mixed  \t\n", "mixed"),
        ("no-trim", "no-trim"),
        ("a b c", "a b c"),                  // interior whitespace preserved
        ("  a b  ", "a b"),                  // interior preserved, edges trimmed
        ("\r\n abc \r\n", "abc"),            // CRLF stripped
    ])
    func trimmingProducesExpectedText(_ input: String, _ expected: String) {
        let trimmed = make(input).trimmingWhitespacesAndNewlines()
        #expect(trimmed.string == expected)
    }

    @Test func trimmingEmptyStringStaysEmpty() {
        #expect(make("").trimmingWhitespacesAndNewlines().string == "")
    }

    @Test func trimmingAllWhitespaceBecomesEmpty() {
        // Pure whitespace: trailing \s+$ removes everything; leading match then
        // operates on the empty remainder.
        #expect(make("   \t\n  ").trimmingWhitespacesAndNewlines().string == "")
    }

    @Test func trimmingSingleSpace() {
        #expect(make(" ").trimmingWhitespacesAndNewlines().string == "")
    }

    @Test func trimmingUnicodeWhitespaceScalars() {
        // The \s character class matches the full Unicode whitespace set, so
        // NBSP (U+00A0) and the line separator (U+2028) are trimmed too.
        #expect(make("\u{00A0}abc\u{00A0}").trimmingWhitespacesAndNewlines().string == "abc")
        #expect(make("\u{2028}abc\u{2028}").trimmingWhitespacesAndNewlines().string == "abc")
        // Vertical tab + form feed.
        #expect(make("\u{000B}\u{000C}abc\u{000C}\u{000B}").trimmingWhitespacesAndNewlines().string == "abc")
    }

    @Test func trimmingPreservesInteriorMultipleSpaces() {
        // Only edge whitespace is removed; runs of interior spaces survive intact.
        #expect(make("  a   b  ").trimmingWhitespacesAndNewlines().string == "a   b")
    }

    @Test func trimmingDoesNotMutateOriginal() {
        let original = make("  abc  ")
        let trimmed = original.trimmingWhitespacesAndNewlines()
        // Source is value type; original must be unchanged.
        #expect(original.string == "  abc  ")
        #expect(trimmed.string == "abc")
    }

    @Test func trimmingNoWhitespaceIsIdentity() {
        let a = make("solid")
        #expect(a.trimmingWhitespacesAndNewlines().string == "solid")
    }

    @Test func trimmingLeadingOnly() {
        #expect(make("   leading").trimmingWhitespacesAndNewlines().string == "leading")
    }

    @Test func trimmingTrailingOnly() {
        #expect(make("trailing   ").trimmingWhitespacesAndNewlines().string == "trailing")
    }

    @Test func trimmingPreservesInteriorNewlines() {
        let a = make("  line1\nline2  ")
        #expect(a.trimmingWhitespacesAndNewlines().string == "line1\nline2")
    }

    @Test func trimmingPreservesAttributesOnRemainingText() throws {
        // Apply an attribute to the whole string, then trim; the non-whitespace
        // run must keep its attribute.
        var a = make("  HELLO  ")
        let full = a.startIndex ..< a.endIndex
        a[full].foregroundColor = .red
        let trimmed = a.trimmingWhitespacesAndNewlines()
        #expect(trimmed.string == "HELLO")
        // The remaining run should still carry the color attribute.
        let firstRun = try #require(trimmed.runs.first)
        #expect(firstRun.foregroundColor == .red)
    }

    // MARK: - AttributedSubstring protocol conformance (slice usage)

    @Test func protocolMethodsWorkOnSubstring() {
        // .ranges and .split are on AttributedStringProtocol, so they should
        // also work when invoked on an AttributedSubstring slice.
        let a = make("xx-yy-zz")
        let slice = a[a.startIndex ..< a.endIndex] // AttributedSubstring
        let ranges = slice.ranges(of: "-")
        #expect(ranges.count == 2)
        let parts = slice.split(separator: "-").map { String($0.characters[...]) }
        #expect(parts == ["xx", "yy", "zz"])
        #expect(slice.string == "xx-yy-zz")
    }

    @Test func protocolMethodsWorkOnInnerSlice() {
        // A proper sub-slice (not the whole string) must split relative to the
        // slice's own bounds, not the parent's.
        let a = make("AA,bb,cc,DD")
        // Drop the leading "AA," and trailing ",DD" to get "bb,cc".
        let chars = a.characters
        let lower = chars.index(a.startIndex, offsetBy: 3)
        let upper = chars.index(a.endIndex, offsetBy: -3)
        let slice = a[lower ..< upper]
        #expect(slice.string == "bb,cc")
        let parts = slice.split(separator: ",").map { String($0.characters[...]) }
        #expect(parts == ["bb", "cc"])
    }

    // MARK: - Concurrency (deterministic, no sleeps)

    @Test func rangesConcurrentReadsAreConsistent() async {
        // AttributedString is a Sendable value type; concurrent reads must all
        // produce the identical result with no crashes / data races.
        let a = make(String(repeating: "ab-", count: 1_000))
        let expected = a.ranges(of: "-").count
        #expect(expected == 1_000)
        await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 500 {
                group.addTask { a.ranges(of: "-").count }
            }
            var observed = 0
            for await c in group {
                #expect(c == expected)
                observed += 1
            }
            #expect(observed == 500)
        }
    }

    @Test func splitConcurrentReadsAreConsistent() async {
        let a = make("alpha,beta,gamma,delta")
        let expected = texts(a.split(separator: ","))
        #expect(expected == ["alpha", "beta", "gamma", "delta"])
        await withTaskGroup(of: [String].self) { group in
            for _ in 0 ..< 500 {
                group.addTask { a.split(separator: ",").map { String($0.characters[...]) } }
            }
            var observed = 0
            for await parts in group {
                #expect(parts == expected)
                observed += 1
            }
            #expect(observed == 500)
        }
    }

    @Test func trimmingConcurrentIsPure() async {
        let a = make("   payload   ")
        await withTaskGroup(of: String.self) { group in
            for _ in 0 ..< 500 {
                group.addTask { a.trimmingWhitespacesAndNewlines().string }
            }
            var observed = 0
            for await s in group {
                #expect(s == "payload")
                observed += 1
            }
            #expect(observed == 500)
        }
        // Original is untouched after concurrent use.
        #expect(a.string == "   payload   ")
    }
}
