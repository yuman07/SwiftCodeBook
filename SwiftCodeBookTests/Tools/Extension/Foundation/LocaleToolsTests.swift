//
//  LocaleToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/Locale+Tools.swift
//  Covers the public `Locale` extension:
//    - var bcp47Identifier: String
//      which takes `identifier`, keeps everything before the first "@"
//      (dropping the keyword suffix), then replaces every "_" with "-".
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct LocaleToolsTests {

    // MARK: - Helpers

    /// Reference re-implementation that mirrors the source line *exactly*:
    ///   (identifier.components(separatedBy: "@").first ?? identifier).replacing("_", with: "-")
    /// Used to assert `bcp47Identifier` follows the documented contract for any
    /// arbitrary identifier string, independent of platform ICU canonicalization.
    private static func expectedBCP47(forIdentifier identifier: String) -> String {
        (identifier.components(separatedBy: "@").first ?? identifier)
            .replacing("_", with: "-")
    }

    // MARK: - Core happy path

    @Test func simpleLanguageRegionUsesDash() {
        // Locale canonicalizes "en_US" -> identifier "en_US"; the property
        // turns the "_" into "-".
        let locale = Locale(identifier: "en_US")
        #expect(locale.bcp47Identifier == "en-US")
    }

    @Test func dashSeparatedInputStaysDashed() {
        let locale = Locale(identifier: "en-US")
        #expect(locale.bcp47Identifier == "en-US")
    }

    @Test func languageOnlyHasNoSeparator() {
        let locale = Locale(identifier: "en")
        #expect(locale.bcp47Identifier == "en")
    }

    // MARK: - The "@" keyword-suffix stripping

    @Test func stripsCalendarAndNumbersKeywordSuffix() {
        // The doc-comment's motivating example.
        let identifier = "ar-SA@calendar=gregorian;numbers=latn"
        let locale = Locale(identifier: identifier)
        // Whatever ICU canonicalizes this to, the part before "@" must survive
        // and the part from "@" onward must be dropped.
        let result = locale.bcp47Identifier
        #expect(!result.contains("@"))
        #expect(!result.contains("calendar"))
        #expect(!result.contains("numbers"))
        #expect(!result.contains("="))
        #expect(!result.contains(";"))
        // And it must match the reference transform of the actual identifier.
        #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier))
        // The language-region prefix must still be present.
        #expect(result.lowercased().hasPrefix("ar"))
    }

    @Test func stripsSingleKeywordSuffix() {
        let locale = Locale(identifier: "zh-Hans-CN@calendar=chinese")
        let result = locale.bcp47Identifier
        #expect(!result.contains("@"))
        #expect(!result.contains("calendar"))
        #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier))
    }

    // Verify the "@" stripping actually exercises the source's split, not only
    // the reference: confirm a Locale that *retains* an "@" keyword in its
    // canonical identifier loses it through the property.
    @Test func keywordSuffixIsActuallyDroppedByProperty() {
        let locale = Locale(identifier: "en_US@calendar=japanese;numbers=arab")
        // If ICU kept the keyword suffix, the raw identifier still has "@",
        // but bcp47Identifier must not.
        if locale.identifier.contains("@") {
            #expect(locale.bcp47Identifier == Self.expectedBCP47(forIdentifier: locale.identifier))
            #expect(locale.bcp47Identifier.count < locale.identifier.count)
        }
        #expect(!locale.bcp47Identifier.contains("@"))
    }

    // MARK: - Underscore -> dash replacement (independent of "@")

    @Test func replacesAllUnderscoresWithDashes() {
        let locale = Locale(identifier: "zh_Hans_CN")
        let result = locale.bcp47Identifier
        #expect(!result.contains("_"))
        #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier))
    }

    // MARK: - Raw-string transform edge cases
    //
    // `Locale(identifier:)` canonicalizes its input, so it cannot be coerced
    // into holding arbitrary pathological strings. These tests drive the
    // *documented transform* (mirrored by `expectedBCP47`) directly to lock
    // down its boundary behavior, which is the contract the source promises.

    @Test func referenceEmptyStringMapsToEmpty() {
        #expect(Self.expectedBCP47(forIdentifier: "") == "")
    }

    @Test func referenceLeadingAtSignYieldsEmptyPrefix() {
        // "components(separatedBy:)" splits on the *first* "@"; a leading "@"
        // leaves an empty prefix.
        #expect(Self.expectedBCP47(forIdentifier: "@calendar=gregorian") == "")
    }

    @Test func referenceOnlyAtSignYieldsEmpty() {
        #expect(Self.expectedBCP47(forIdentifier: "@") == "")
    }

    @Test func referenceSplitsOnFirstAtSignOnly() {
        // Everything from the first "@" onward is dropped, even later "@"s.
        #expect(Self.expectedBCP47(forIdentifier: "a@b@c") == "a")
        #expect(Self.expectedBCP47(forIdentifier: "en_US@x@y") == "en-US")
    }

    @Test func referenceReplacesEveryUnderscore() {
        #expect(Self.expectedBCP47(forIdentifier: "a_b_c_d") == "a-b-c-d")
        #expect(Self.expectedBCP47(forIdentifier: "_leading") == "-leading")
        #expect(Self.expectedBCP47(forIdentifier: "trailing_") == "trailing-")
        #expect(Self.expectedBCP47(forIdentifier: "___") == "---")
    }

    @Test func referencePreservesUnicodeAndDropsAfterAt() {
        // Non-ASCII content is untouched except for the "_" -> "-" rule, and
        // the keyword suffix after "@" is dropped.
        #expect(Self.expectedBCP47(forIdentifier: "ünïcödé_x@drop_me") == "ünïcödé-x")
        #expect(Self.expectedBCP47(forIdentifier: "日本_語") == "日本-語")
    }

    @Test func referenceNoSeparatorsIsIdentity() {
        #expect(Self.expectedBCP47(forIdentifier: "en") == "en")
        #expect(Self.expectedBCP47(forIdentifier: "abcDEF123") == "abcDEF123")
    }

    // Documents that `components(separatedBy:)` always returns at least one
    // element, so the source's `?? identifier` fallback branch is unreachable.
    // (If this invariant ever changed, the source's behavior on empty input
    // would differ from what the reference assumes.)
    @Test func componentsBySeparatorIsNeverEmpty() {
        #expect("".components(separatedBy: "@").first != nil)
        #expect("".components(separatedBy: "@").first == "")
        #expect("@".components(separatedBy: "@").first == "")
        #expect("@".components(separatedBy: "@").count == 2)
        #expect("a@b@c".components(separatedBy: "@").first == "a")
    }

    // MARK: - Contract verification across a table of identifiers

    // Each row is a raw identifier string; we assert that the property's output
    // equals the reference transform applied to the *canonicalized* identifier.
    @Test(arguments: [
        "en",
        "en_US",
        "en-US",
        "fr_FR",
        "de_DE",
        "ja_JP",
        "zh_Hans_CN",
        "zh-Hant-TW",
        "pt_BR",
        "es_419",
        "ar_SA",
        "ar-SA@calendar=gregorian;numbers=latn",
        "en_US@calendar=gregorian",
        "und",
        "",
    ])
    func matchesReferenceTransform(identifier: String) {
        let locale = Locale(identifier: identifier)
        #expect(locale.bcp47Identifier == Self.expectedBCP47(forIdentifier: locale.identifier))
    }

    // MARK: - Invariants on output shape

    @Test(arguments: [
        "en_US",
        "ar-SA@calendar=gregorian;numbers=latn",
        "zh_Hans_CN@calendar=chinese",
        "en_US@calendar=gregorian",
    ])
    func outputNeverContainsUnderscoreOrAtSign(identifier: String) {
        let locale = Locale(identifier: identifier)
        let result = locale.bcp47Identifier
        #expect(!result.contains("_"))
        #expect(!result.contains("@"))
    }

    // MARK: - Idempotence

    @Test func transformIsIdempotentOnItsOwnOutput() {
        // The produced bcp47 identifier already has no "_" or "@", so applying
        // the transform again must be a no-op.
        let locale = Locale(identifier: "ar-SA@calendar=gregorian;numbers=latn")
        let once = locale.bcp47Identifier
        let twice = Self.expectedBCP47(forIdentifier: once)
        #expect(once == twice)
        // And re-canonicalizing through Locale must also be stable on shape.
        let reLocale = Locale(identifier: once)
        #expect(!reLocale.bcp47Identifier.contains("_"))
        #expect(!reLocale.bcp47Identifier.contains("@"))
    }

    // MARK: - Well-known system locales

    @Test func currentLocaleProducesNonEmptyDashFormForKnownLocales() {
        // For any concrete language locale the result must be non-empty,
        // separator-clean, and match the reference transform.
        for id in ["en_US", "fr_CA", "de_CH", "pt_BR", "ko_KR"] {
            let locale = Locale(identifier: id)
            let result = locale.bcp47Identifier
            #expect(!result.isEmpty)
            #expect(!result.contains("_"))
            #expect(!result.contains("@"))
            #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier))
        }
    }

    // MARK: - Boundary / edge identifiers

    @Test func emptyIdentifierLocale() {
        let locale = Locale(identifier: "")
        // Empty identifier canonicalizes to some value (often ""); the property
        // must still equal the reference transform and contain no "_" or "@".
        let result = locale.bcp47Identifier
        #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier))
        #expect(!result.contains("_"))
        #expect(!result.contains("@"))
    }

    @Test func availableIdentifiersAllSatisfyContract() {
        // Large-but-bounded sweep over every available locale on the platform.
        // Asserts the universal invariants hold for all of them.
        let ids = Locale.availableIdentifiers
        #expect(!ids.isEmpty)
        for id in ids {
            let locale = Locale(identifier: id)
            let result = locale.bcp47Identifier
            #expect(!result.contains("_"), "underscore leaked for id \(id) -> \(result)")
            #expect(!result.contains("@"), "@ leaked for id \(id) -> \(result)")
            #expect(result == Self.expectedBCP47(forIdentifier: locale.identifier),
                    "mismatch for id \(id)")
        }
    }

    // MARK: - Concurrency

    @Test func concurrentAccessIsConsistent() async {
        // The property is a pure read on an immutable value type; hammer it from
        // many tasks and assert every task computes the identical result.
        let locale = Locale(identifier: "ar-SA@calendar=gregorian;numbers=latn")
        let expected = locale.bcp47Identifier

        let results = await withTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<1000 {
                group.addTask { locale.bcp47Identifier }
            }
            var collected: [String] = []
            for await r in group {
                collected.append(r)
            }
            return collected
        }

        #expect(results.count == 1000)
        #expect(results.allSatisfy { $0 == expected })
    }

    @Test func concurrentAcrossManyLocalesMatchesReference() async {
        let ids = ["en_US", "zh_Hans_CN", "fr_FR", "ar-SA@calendar=gregorian;numbers=latn",
                   "ja_JP", "de_DE", "pt_BR", "ko_KR", "es_419", "en"]

        let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<200 {
                for id in ids {
                    group.addTask {
                        let locale = Locale(identifier: id)
                        return locale.bcp47Identifier == Self.expectedBCP47(forIdentifier: locale.identifier)
                    }
                }
            }
            var failed = 0
            for await passed in group where !passed {
                failed += 1
            }
            return failed
        }

        #expect(failures == 0)
    }

    // MARK: - Large-data string handling

    @Test func longSyntheticIdentifierWithManyUnderscoresAndKeywords() {
        // Drive the documented transform directly with a pathological string to
        // verify the "@"-split + "_"-replace logic on large input. We can't force
        // Locale to keep an arbitrary huge identifier, so validate the documented
        // transformation via the reference.
        let segmentCount = 20_000
        let prefix = Array(repeating: "x_y", count: segmentCount).joined(separator: "_")
        let synthetic = prefix + "@calendar=gregorian;numbers=latn"
        let transformed = Self.expectedBCP47(forIdentifier: synthetic)
        #expect(!transformed.contains("_"))
        #expect(!transformed.contains("@"))
        #expect(transformed.hasPrefix("x-y"))
        #expect(transformed.hasSuffix("x-y"))
        // Each "x_y" segment becomes "x-y" and segments are joined by "_"->"-".
        // So the whole prefix is just every "x" and "y" joined by "-".
        let expectedDashes = transformed.filter { $0 == "-" }.count
        // segmentCount segments of "x-y" (1 dash each) + (segmentCount-1) join dashes.
        #expect(expectedDashes == segmentCount + (segmentCount - 1))
    }
}
