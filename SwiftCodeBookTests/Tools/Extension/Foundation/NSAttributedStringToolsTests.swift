//
//  NSAttributedStringToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/NSAttributedString+Tools.swift
//  Covers NSAttributedString.fullRange, .trimmingCharacters(in:) and
//  .split(separator:options:locale:keepSeparator:omittingEmptySubsequences:).
//  These exercise the helpers NSString.ranges(of:) / isValidRange and
//  NSRange.isValid indirectly through the public surface.
//

import Testing
import Foundation
import UIKit
@testable import SwiftCodeBook

@Suite struct NSAttributedStringToolsTests {

    // MARK: - Helpers

    /// Builds a plain NSAttributedString from text.
    private func make(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string)
    }

    /// Builds an attributed string carrying a single foreground color,
    /// so we can assert that splitting / trimming preserves attributes.
    private func makeColored(_ string: String, color: UIColor = .red) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.foregroundColor: color])
    }

    /// Plain text of each component, in order.
    private func texts(_ parts: [NSAttributedString]) -> [String] {
        parts.map(\.string)
    }

    /// Foreground color at the given UTF-16 index, if any.
    private func color(of attributed: NSAttributedString, at index: Int) -> UIColor? {
        attributed.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
    }

    // MARK: - fullRange

    @Test func fullRangeOnEmpty() {
        let s = make("")
        #expect(s.fullRange == NSRange(location: 0, length: 0))
        #expect(s.fullRange.length == 0)
    }

    @Test func fullRangeBasicASCII() {
        let s = make("Hello")
        #expect(s.fullRange == NSRange(location: 0, length: 5))
        #expect(s.fullRange.location == 0)
        #expect(s.fullRange.length == s.length)
    }

    @Test func fullRangeWithEmojiUsesUTF16Length() {
        // "👍" is a single Character but length 2 in UTF-16 (NSString length).
        let s = make("a👍b")
        #expect(s.fullRange == NSRange(location: 0, length: 4))
        #expect(s.fullRange.length == ("a👍b" as NSString).length)
    }

    @Test func fullRangeWithFlagEmojiCountsAllSurrogates() {
        // A flag is two regional-indicator symbols => 4 UTF-16 units.
        let s = make("🇨🇳")
        #expect(s.fullRange == NSRange(location: 0, length: 4))
        #expect(s.fullRange.length == ("🇨🇳" as NSString).length)
    }

    @Test func fullRangeWithCombiningCharacters() {
        // "é" written as e + combining acute accent: 2 UTF-16 units.
        let s = make("e\u{0301}")
        #expect(s.fullRange == NSRange(location: 0, length: 2))
    }

    @Test(arguments: [
        ("", 0),
        ("x", 1),
        ("hello world", 11),
        ("café", 4),
    ])
    func fullRangeLengthMatchesNSString(text: String, expected: Int) {
        #expect(make(text).fullRange == NSRange(location: 0, length: expected))
        #expect(make(text).fullRange.length == (text as NSString).length)
    }

    // MARK: - trimmingCharacters(in:) — happy path

    @Test func trimmingWhitespacesBothSides() {
        let result = make("   hello   ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "hello")
        #expect(result.length == 5)
    }

    @Test func trimmingLeadingOnly() {
        let result = make("\t\t hi").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "hi")
    }

    @Test func trimmingTrailingOnly() {
        let result = make("hi   ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "hi")
    }

    @Test func trimmingNothingToTrimReturnsEqualContent() {
        let result = make("hello").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "hello")
    }

    @Test func trimmingNothingToTrimReturnsSelfIdentity() {
        // When the kept range equals fullRange, the impl returns `self` (same instance).
        let original = make("hello")
        let result = original.trimmingCharacters(in: .whitespaces)
        #expect(result === original)
    }

    @Test func trimmingSingleNonTrimmedCharacterReturnsSelfIdentity() {
        // No whitespace at all => kept range == fullRange => identity fast path.
        let original = make("x")
        let result = original.trimmingCharacters(in: .whitespaces)
        #expect(result === original)
        #expect(result.string == "x")
    }

    @Test func trimmingWhitespacesAndNewlines() {
        let result = make("\n\t  abc \n ").trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(result.string == "abc")
    }

    @Test func trimmingKeepsInteriorWhitespace() {
        let result = make("  a b c  ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "a b c")
    }

    // MARK: - trimmingCharacters(in:) — empty / all-trimmed branches

    @Test func trimmingEmptyStringReturnsEmpty() {
        let result = make("").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    @Test func trimmingAllWhitespaceReturnsEmpty() {
        // No character is outside the set -> leading lookup fails -> empty result.
        let result = make("     ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    @Test func trimmingAllNewlinesReturnsEmpty() {
        let result = make("\n\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    @Test func trimmingWithEmptySetTrimsNothing() {
        // Inverted of empty set = everything, so the first/last chars always qualify
        // and the kept range equals fullRange (identity).
        let original = make("  hi  ")
        let result = original.trimmingCharacters(in: CharacterSet())
        #expect(result.string == "  hi  ")
        #expect(result === original)
    }

    @Test func trimmingWithFullSetReturnsEmpty() {
        // Set contains every character -> inverted is empty -> nothing kept -> empty.
        let result = make("anything").trimmingCharacters(in: CharacterSet().inverted)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    @Test func trimmingSingleNonTrimmedCharacter() {
        let result = make("  x  ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "x")
        #expect(result.length == 1)
    }

    @Test func trimmingSingleTrimmedCharacter() {
        let result = make(" ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    // MARK: - trimmingCharacters(in:) — custom sets / unicode

    @Test func trimmingCustomCharacterSet() {
        let set = CharacterSet(charactersIn: "*#")
        let result = make("##*hello*#").trimmingCharacters(in: set)
        #expect(result.string == "hello")
    }

    @Test func trimmingCustomSetKeepsInteriorMatches() {
        // Interior occurrences of the trimmed characters must survive.
        let set = CharacterSet(charactersIn: "*")
        let result = make("**a*b**").trimmingCharacters(in: set)
        #expect(result.string == "a*b")
    }

    @Test func trimmingPunctuation() {
        let result = make("...done!!!").trimmingCharacters(in: .punctuationCharacters)
        #expect(result.string == "done")
    }

    @Test func trimmingDoesNotTouchEmojiWhenTrimmingWhitespace() {
        let result = make("  🎉party🎉  ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "🎉party🎉")
    }

    @Test func trimmingWhitespaceAroundCombiningCharacterKeepsScalars() {
        // The kept content "e + combining acute" must stay intact (2 UTF-16 units).
        let result = make("  e\u{0301}  ").trimmingCharacters(in: .whitespaces)
        #expect(result.string == "e\u{0301}")
        #expect(result.length == 2)
    }

    @Test func trimmingPreservesAttributesOnKeptRange() {
        let s = makeColored("   hello   ", color: .green)
        let result = s.trimmingCharacters(in: .whitespaces)
        #expect(result.string == "hello")
        #expect(color(of: result, at: 0) == .green)
        #expect(color(of: result, at: result.length - 1) == .green)
    }

    @Test func trimmingMixedAttributesKeepsCorrectSegmentAttributes() {
        // "  " (no attr) + "AB" (red) + "  " (no attr)
        let mutable = NSMutableAttributedString(string: "  ")
        mutable.append(NSAttributedString(string: "AB", attributes: [.foregroundColor: UIColor.red]))
        mutable.append(NSAttributedString(string: "  "))
        let result = mutable.trimmingCharacters(in: .whitespaces)
        #expect(result.string == "AB")
        #expect(color(of: result, at: 0) == .red)
        #expect(color(of: result, at: 1) == .red)
    }

    // MARK: - split — happy path

    @Test func splitBasic() {
        let parts = make("a,b,c").split(separator: ",")
        #expect(texts(parts) == ["a", "b", "c"])
    }

    @Test func splitNoSeparatorPresentReturnsWhole() {
        let parts = make("hello").split(separator: ",")
        #expect(texts(parts) == ["hello"])
    }

    @Test func splitMultiCharacterSeparator() {
        let parts = make("a<>b<>c").split(separator: "<>")
        #expect(texts(parts) == ["a", "b", "c"])
    }

    @Test func splitTrailingSeparatorOmitsEmpty() {
        // Trailing separator: after the last sep, location == length so nothing appended.
        let parts = make("a,b,").split(separator: ",")
        #expect(texts(parts) == ["a", "b"])
    }

    @Test func splitLeadingSeparatorOmitsEmpty() {
        let parts = make(",a,b").split(separator: ",")
        #expect(texts(parts) == ["a", "b"])
    }

    @Test func splitConsecutiveSeparatorsOmitEmpty() {
        let parts = make("a,,b").split(separator: ",")
        #expect(texts(parts) == ["a", "b"])
    }

    @Test func splitSeparatorEqualToWholeStringOmits() {
        // The whole string is the separator -> two empty pieces, both omitted.
        let parts = make("abc").split(separator: "abc")
        #expect(parts.isEmpty)
    }

    @Test func splitSeparatorLongerThanStringReturnsWhole() {
        let parts = make("ab").split(separator: "abc")
        #expect(texts(parts) == ["ab"])
    }

    // MARK: - split — overlapping separators (advances by upperBound)

    @Test func splitOverlappingSeparatorAdvancesPastMatch() {
        // "aaa" matches "aa" once at [0,2); the search resumes at index 2 leaving "a".
        let parts = make("aaa").split(separator: "aa")
        #expect(texts(parts) == ["a"])
    }

    @Test func splitOverlappingSeparatorTwoMatchesOmitEmpties() {
        // "aaaa" matches "aa" at [0,2) and [2,4); both surrounding pieces are empty.
        let parts = make("aaaa").split(separator: "aa")
        #expect(parts.isEmpty)
    }

    @Test func splitOverlappingSeparatorTwoMatchesKeepEmpties() {
        let parts = make("aaaa").split(separator: "aa", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["", "", ""])
    }

    // MARK: - split — omittingEmptySubsequences == false

    @Test func splitKeepsEmptyBetweenConsecutiveSeparators() {
        let parts = make("a,,b").split(separator: ",", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["a", "", "b"])
    }

    @Test func splitKeepsLeadingAndTrailingEmpty() {
        let parts = make(",a,").split(separator: ",", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["", "a", ""])
    }

    @Test func splitOnlySeparatorsKeepsAllEmpties() {
        // Three commas -> four empty subsequences when not omitting.
        let parts = make(",,,").split(separator: ",", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["", "", "", ""])
    }

    @Test func splitOnlySeparatorsOmittingYieldsNothing() {
        let parts = make(",,,").split(separator: ",")
        #expect(parts.isEmpty)
    }

    @Test func splitSingleCharEqualToSeparatorOmits() {
        #expect(make("x").split(separator: "x").isEmpty)
    }

    @Test func splitSingleCharEqualToSeparatorKeepsTwoEmpties() {
        let parts = make("x").split(separator: "x", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["", ""])
    }

    // MARK: - split — keepSeparator

    @Test func splitKeepSeparator() {
        let parts = make("a,b,c").split(separator: ",", keepSeparator: true)
        #expect(texts(parts) == ["a", ",", "b", ",", "c"])
    }

    @Test func splitKeepSeparatorWithTrailingSeparator() {
        // After last "," location == length, so no trailing empty piece, but the
        // separator itself is still emitted.
        let parts = make("a,b,").split(separator: ",", keepSeparator: true)
        #expect(texts(parts) == ["a", ",", "b", ","])
    }

    @Test func splitKeepSeparatorWithLeadingSeparator() {
        // Leading separator with omitting: the empty leading piece is dropped but the
        // separator token is still kept.
        let parts = make(",a,b").split(separator: ",", keepSeparator: true)
        #expect(texts(parts) == [",", "a", ",", "b"])
    }

    @Test func splitKeepSeparatorMultiChar() {
        let parts = make("x::y").split(separator: "::", keepSeparator: true)
        #expect(texts(parts) == ["x", "::", "y"])
    }

    @Test func splitKeepSeparatorMultiCharTrailing() {
        let parts = make("x::y::").split(separator: "::", keepSeparator: true)
        #expect(texts(parts) == ["x", "::", "y", "::"])
    }

    @Test func splitKeepSeparatorAndKeepEmpty() {
        let parts = make("a,,b").split(separator: ",", keepSeparator: true, omittingEmptySubsequences: false)
        #expect(texts(parts) == ["a", ",", "", ",", "b"])
    }

    @Test func splitKeepSeparatorLeadingAndKeepEmpty() {
        let parts = make(",a,b").split(separator: ",", keepSeparator: true, omittingEmptySubsequences: false)
        #expect(texts(parts) == ["", ",", "a", ",", "b"])
    }

    // MARK: - split — options / case insensitivity

    @Test func splitCaseInsensitive() {
        let parts = make("aXbxc").split(separator: "x", options: [.caseInsensitive])
        #expect(texts(parts) == ["a", "b", "c"])
    }

    @Test func splitCaseSensitiveByDefault() {
        // Only the lowercase "x" (index 3) matches; the uppercase "X" stays in place.
        let parts = make("aXbxc").split(separator: "x")
        #expect(texts(parts) == ["aXb", "c"])
    }

    @Test func splitCaseInsensitiveMultiChar() {
        let parts = make("aSEPbsepc").split(separator: "sep", options: [.caseInsensitive])
        #expect(texts(parts) == ["a", "b", "c"])
    }

    // MARK: - split — empty inputs / edge separators

    @Test func splitEmptyStringReturnsEmpty() {
        let parts = make("").split(separator: ",")
        #expect(parts.isEmpty)
    }

    @Test func splitEmptyStringNotOmittingYieldsOneEmpty() {
        // location(0) < length(0) is false, but !omitting forces one append.
        let parts = make("").split(separator: ",", omittingEmptySubsequences: false)
        #expect(texts(parts) == [""])
    }

    @Test func splitWithEmptySeparatorReturnsWhole() {
        // range(of: "") yields {NSNotFound, 0}, which fails isValidRange, so
        // ranges(of: "") is empty and the whole string is returned as one piece.
        let parts = make("abc").split(separator: "")
        #expect(texts(parts) == ["abc"])
    }

    @Test func splitEmptyStringWithEmptySeparatorReturnsEmpty() {
        // Empty content + empty separator: no ranges and location(0) < length(0) is
        // false, so nothing is appended when omitting.
        let parts = make("").split(separator: "")
        #expect(parts.isEmpty)
    }

    @Test func splitSeparatorNotFoundNotOmitting() {
        let parts = make("abc").split(separator: ",", omittingEmptySubsequences: false)
        #expect(texts(parts) == ["abc"])
    }

    // MARK: - split — unicode / emoji boundaries

    @Test func splitWithEmojiContent() {
        let parts = make("🍎,🍌,🍇").split(separator: ",")
        #expect(texts(parts) == ["🍎", "🍌", "🍇"])
    }

    @Test func splitOnEmojiSeparator() {
        let parts = make("a👍b👍c").split(separator: "👍")
        #expect(texts(parts) == ["a", "b", "c"])
    }

    @Test func splitOnFlagEmojiSeparator() {
        // The separator spans 4 UTF-16 units; pieces must land on scalar boundaries.
        let parts = make("a🇨🇳b🇨🇳c").split(separator: "🇨🇳")
        #expect(texts(parts) == ["a", "b", "c"])
    }

    @Test func splitWhitespaceSeparator() {
        let parts = make("one two three").split(separator: " ")
        #expect(texts(parts) == ["one", "two", "three"])
    }

    // MARK: - split — attribute preservation

    @Test func splitPreservesAttributes() {
        let s = makeColored("a,b", color: .blue)
        let parts = s.split(separator: ",")
        #expect(texts(parts) == ["a", "b"])
        for part in parts {
            #expect(color(of: part, at: 0) == .blue)
        }
    }

    @Test func splitPreservesPerSegmentAttributes() {
        // "AA" red, ",", "BB" green
        let mutable = NSMutableAttributedString(string: "AA", attributes: [.foregroundColor: UIColor.red])
        mutable.append(NSAttributedString(string: ","))
        mutable.append(NSAttributedString(string: "BB", attributes: [.foregroundColor: UIColor.green]))
        let parts = mutable.split(separator: ",")
        #expect(texts(parts) == ["AA", "BB"])
        #expect(color(of: parts[0], at: 0) == .red)
        #expect(color(of: parts[0], at: 1) == .red)
        #expect(color(of: parts[1], at: 0) == .green)
        #expect(color(of: parts[1], at: 1) == .green)
    }

    @Test func splitKeepSeparatorPreservesSeparatorAttributes() {
        // The kept separator token must retain its own attribute run.
        let mutable = NSMutableAttributedString(string: "a", attributes: [.foregroundColor: UIColor.red])
        mutable.append(NSAttributedString(string: ",", attributes: [.foregroundColor: UIColor.green]))
        mutable.append(NSAttributedString(string: "b", attributes: [.foregroundColor: UIColor.blue]))
        let parts = mutable.split(separator: ",", keepSeparator: true)
        #expect(texts(parts) == ["a", ",", "b"])
        #expect(color(of: parts[0], at: 0) == .red)
        #expect(color(of: parts[1], at: 0) == .green)
        #expect(color(of: parts[2], at: 0) == .blue)
    }

    // MARK: - split — round trips

    @Test(arguments: [
        ["a", "b", "c"],
        ["hello", "world"],
        ["single"],
        ["x", "yy", "zzz"],
    ])
    func splitJoinRoundTrip(components: [String]) {
        let joined = components.joined(separator: "|")
        let parts = make(joined).split(separator: "|")
        #expect(texts(parts) == components)
    }

    @Test func splitJoinRoundTripKeepSeparatorReconstructs() {
        let original = "alpha-beta-gamma"
        let parts = make(original).split(separator: "-", keepSeparator: true)
        let reconstructed = parts.map(\.string).joined()
        #expect(reconstructed == original)
    }

    @Test func splitNotOmittingPlusJoinReconstructsExactly() {
        // With empty subsequences kept, joining on the separator must reproduce input.
        let original = ",a,,b,"
        let parts = make(original).split(separator: ",", omittingEmptySubsequences: false)
        #expect(parts.map(\.string).joined(separator: ",") == original)
    }

    // MARK: - Large, time-bounded data

    @Test func splitLargeInput() {
        let count = 100_000
        let joined = Array(repeating: "x", count: count).joined(separator: ",")
        let parts = make(joined).split(separator: ",")
        #expect(parts.count == count)
        #expect(parts.first?.string == "x")
        #expect(parts.last?.string == "x")
    }

    @Test func splitLargeInputNoSeparatorReturnsWhole() {
        let big = String(repeating: "a", count: 100_000)
        let parts = make(big).split(separator: ",")
        #expect(parts.count == 1)
        #expect(parts.first?.length == 100_000)
    }

    @Test func trimmingLargeWhitespacePaddedInput() {
        let pad = String(repeating: " ", count: 50_000)
        let s = make(pad + "core" + pad)
        let result = s.trimmingCharacters(in: .whitespaces)
        #expect(result.string == "core")
    }

    @Test func trimmingLargeAllWhitespaceReturnsEmpty() {
        let s = make(String(repeating: " ", count: 100_000))
        let result = s.trimmingCharacters(in: .whitespaces)
        #expect(result.string == "")
        #expect(result.length == 0)
    }

    // MARK: - Concurrency
    //
    // NSAttributedString is explicitly NOT Sendable under Swift 6, so we never pass an
    // instance across the task boundary. Each child task constructs its own instance
    // from a Sendable String and exercises the API independently; the operations must
    // be re-entrant and yield identical results every time.

    @Test func concurrentSplitProducesConsistentResults() async {
        let text = "a,b,c,d,e,f,g,h"
        let expected = ["a", "b", "c", "d", "e", "f", "g", "h"]
        let results = await withTaskGroup(of: [String].self) { group in
            for _ in 0..<500 {
                group.addTask {
                    NSAttributedString(string: text).split(separator: ",").map(\.string)
                }
            }
            var collected = [[String]]()
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 == expected })
    }

    @Test func concurrentTrimmingProducesConsistentResults() async {
        let text = "   trimmed value   "
        let seen = await withTaskGroup(of: String.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    NSAttributedString(string: text).trimmingCharacters(in: .whitespaces).string
                }
            }
            var collected = Set<String>()
            for await value in group {
                collected.insert(value)
            }
            return collected
        }
        #expect(seen == ["trimmed value"])
    }

    @Test func concurrentFullRangeIsStable() async {
        let text = "stable content here"
        let expected = NSRange(location: 0, length: (text as NSString).length)
        let allOK = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    NSAttributedString(string: text).fullRange == expected
                }
            }
            var ok = true
            for await result in group {
                ok = ok && result
            }
            return ok
        }
        #expect(allOK)
    }
}
