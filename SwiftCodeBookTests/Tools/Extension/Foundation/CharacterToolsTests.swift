//
//  CharacterToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/Character+Tools.swift
//  Covers the public `Character.isEmoji` computed property, whose rule is:
//    isEmoji == scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
//  where `scalar` is the FIRST unicode scalar of the character.
//
//  Notable behaviours exercised:
//   - Genuine single-scalar emoji above 0x238C (e.g. 😀, ✅) -> true.
//   - Single ASCII digits like "3" -> false even though their scalar has
//     `isEmoji == true`, because they are below 0x238C with a single scalar.
//   - Keycap sequences like "3️⃣" -> true (multiple scalars).
//   - Non-emoji characters (letters, punctuation, whitespace) -> false.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct CharacterToolsTests {

    // MARK: - Helpers

    /// Recomputes the source rule directly from scalars, used to cross-check
    /// the property implementation against the documented contract.
    private static func referenceIsEmoji(_ c: Character) -> Bool {
        guard let scalar = c.unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || c.unicodeScalars.count > 1)
    }

    // MARK: - Happy path: genuine single-scalar emoji (value > 0x238C)

    @Test(arguments: [
        Character("😀"), // U+1F600
        Character("😎"), // U+1F60E
        Character("🎉"), // U+1F389
        Character("🚀"), // U+1F680
        Character("❤"),  // U+2764 (heart, > 0x238C)
        Character("✅"),  // U+2705 (> 0x238C)
        Character("⭐"),  // U+2B50
        Character("🍎"), // U+1F34E
        Character("🐶"), // U+1F436
        Character("🌍"), // U+1F30D
    ])
    func genuineEmojiAboveBoundaryAreEmoji(_ c: Character) {
        #expect(c.isEmoji)
    }

    // MARK: - Multi-scalar emoji sequences (count > 1 branch)

    @Test func keycapDigitIsEmoji() {
        // "3️⃣" = "3" + VARIATION SELECTOR-16 + COMBINING ENCLOSING KEYCAP.
        // First scalar is digit 3 (isEmoji true, value < 0x238C), but the
        // character has more than one scalar so the count > 1 branch makes it true.
        let keycap = Character("3️⃣")
        #expect(keycap.unicodeScalars.count > 1)
        #expect(keycap.isEmoji)
    }

    @Test func keycapHashIsEmoji() {
        // "#️⃣" keycap. First scalar '#' has isEmoji == true.
        let keycap = Character("#️⃣")
        #expect(keycap.unicodeScalars.count > 1)
        #expect(keycap.isEmoji)
    }

    @Test func flagEmojiIsEmoji() {
        // Regional indicator pair: 🇺🇸. First scalar is a regional indicator
        // (value > 0x238C) and there are two scalars.
        let flag = Character("🇺🇸")
        #expect(flag.unicodeScalars.count > 1)
        #expect(flag.isEmoji)
    }

    @Test func emojiWithSkinToneModifierIsEmoji() {
        // 👍🏽 thumbs up + medium skin tone modifier (multi-scalar).
        let thumbsUp = Character("👍🏽")
        #expect(thumbsUp.unicodeScalars.count > 1)
        #expect(thumbsUp.isEmoji)
    }

    @Test func zwjFamilySequenceIsEmoji() {
        // 👨‍👩‍👧‍👦 ZWJ family sequence: many scalars, first is an emoji scalar.
        let family = Character("👨‍👩‍👧‍👦")
        #expect(family.unicodeScalars.count > 1)
        #expect(family.isEmoji)
    }

    // MARK: - The 0x238C boundary with single-scalar "ambiguous" emoji

    @Test func asciiDigitThreeIsNotEmoji() {
        // SUSPECTED-NOT-A-BUG documentation: the standard library reports
        // Unicode.Scalar("3").properties.isEmoji == true, but the source rule
        // requires value > 0x238C (3 is U+0033) OR multiple scalars. A bare "3"
        // is a single scalar below the boundary, so isEmoji must be false.
        let three = Character("3")
        #expect(three.unicodeScalars.count == 1)
        #expect(!three.isEmoji)
    }

    @Test(arguments: [
        Character("0"),
        Character("1"),
        Character("2"),
        Character("3"),
        Character("4"),
        Character("5"),
        Character("6"),
        Character("7"),
        Character("8"),
        Character("9"),
        Character("#"),
        Character("*"),
    ])
    func bareAsciiEmojiBaseCharactersAreNotEmoji(_ c: Character) {
        // These ASCII characters all have `isEmoji == true` at the scalar level,
        // yet are single-scalar and below 0x238C, so the property is false.
        #expect(c.unicodeScalars.count == 1)
        #expect(!c.isEmoji)
    }

    // MARK: - Non-emoji characters

    @Test(arguments: [
        Character("a"),
        Character("Z"),
        Character("z"),
        Character(" "),
        Character("\t"),
        Character("\n"),
        Character("."),
        Character(","),
        Character("!"),
        Character("?"),
        Character("-"),
        Character("_"),
        Character("@"),
        Character("$"),
        Character("%"),
        Character("^"),
        Character("&"),
        Character("("),
        Character(")"),
    ])
    func plainCharactersAreNotEmoji(_ c: Character) {
        #expect(!c.isEmoji)
    }

    @Test(arguments: [
        Character("é"),  // Latin small e with acute
        Character("ñ"),
        Character("ü"),
        Character("中"), // CJK
        Character("文"),
        Character("あ"), // Hiragana
        Character("가"), // Hangul
        Character("Ω"),  // Greek capital omega (U+03A9)
        Character("α"),  // Greek small alpha
        Character("я"),  // Cyrillic
        Character("ع"),  // Arabic
    ])
    func nonLatinLettersAreNotEmoji(_ c: Character) {
        #expect(!c.isEmoji)
    }

    @Test func combiningCharacterIsNotEmoji() {
        // "é" composed as e + combining acute accent. First scalar 'e' is not
        // an emoji scalar, so despite having count > 1 the property is false
        // (the AND short-circuits on isEmoji == false).
        let composed = Character("e\u{0301}")
        #expect(composed.unicodeScalars.count > 1)
        #expect(!composed.isEmoji)
    }

    // MARK: - Cross-check against the documented reference rule

    @Test(arguments: [
        Character("😀"),
        Character("3"),
        Character("3️⃣"),
        Character("a"),
        Character("❤"),
        Character("👍🏽"),
        Character("中"),
        Character("#️⃣"),
        Character("🇺🇸"),
        Character(" "),
    ])
    func matchesReferenceImplementation(_ c: Character) {
        #expect(c.isEmoji == Self.referenceIsEmoji(c))
    }

    // MARK: - Determinism / purity

    @Test func repeatedAccessIsStable() {
        let emoji = Character("🎈")
        let nonEmoji = Character("x")
        #expect(emoji.isEmoji)
        #expect(emoji.isEmoji) // second read, same value
        #expect(!nonEmoji.isEmoji)
        #expect(!nonEmoji.isEmoji)
    }

    // MARK: - Driving the property across a whole String's characters

    @Test func filteringEmojiFromMixedString() {
        // A mix of emoji and plain text; only the genuine emoji should pass.
        let mixed = "a😀b🎉c🚀d"
        let emojis = mixed.filter { $0.isEmoji }
        #expect(emojis == "😀🎉🚀")
    }

    @Test func plainStringHasNoEmoji() {
        let text = "Hello, World! 123"
        #expect(text.allSatisfy { !$0.isEmoji })
    }

    // MARK: - Large, time-bounded input

    @Test func largeStringIsEmojiScanIsCorrect() {
        // Build a long alternating string of emoji and letters, then count the
        // emoji via the property. 100_000 chars total, well under a second.
        let pairCount = 50_000
        var s = String()
        s.reserveCapacity(pairCount * 2)
        for _ in 0..<pairCount {
            s.append("😀")
            s.append("x")
        }
        let emojiCount = s.reduce(into: 0) { partial, c in
            if c.isEmoji { partial += 1 }
        }
        #expect(emojiCount == pairCount)
    }

    @Test func largeNonEmojiStringHasNoFalsePositives() {
        let s = String(repeating: "Ab1 .", count: 20_000) // 100_000 chars
        #expect(s.allSatisfy { !$0.isEmoji })
    }

    // MARK: - Concurrency: isEmoji is a pure read of an immutable value

    @Test func concurrentReadsAreConsistent() async {
        let emoji = Character("🦄")
        let nonEmoji = Character("q")
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for i in 0..<500 {
                group.addTask {
                    // Alternate which character each task evaluates.
                    (i % 2 == 0) ? emoji.isEmoji : !nonEmoji.isEmoji
                }
            }
            var collected = [Bool]()
            for await r in group {
                collected.append(r)
            }
            return collected
        }
        #expect(results.count == 500)
        // Every task must observe the correct, stable answer.
        #expect(results.allSatisfy { $0 })
    }
}
