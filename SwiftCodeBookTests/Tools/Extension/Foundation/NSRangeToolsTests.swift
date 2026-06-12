//
//  NSRangeToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests (Swift Testing) for:
//    Source/Tools/Extension/Foundation/NSRange+Tools.swift
//
//  Source under test exposes a single public computed property on NSRange:
//    var isValid: Bool {
//        location >= 0 && location != NSNotFound && length >= 0 && length <= Int.max - location
//    }
//
//  Notes on the logic (NSNotFound == Int.max on all Apple platforms):
//    1. location must be non-negative.
//    2. location must not equal NSNotFound (== Int.max) — the sentinel used by
//       Foundation for "not found".
//    3. length must be non-negative.
//    4. location + length must not overflow Int, expressed safely as
//       length <= Int.max - location. Because of short-circuiting, by the time
//       this term is evaluated we already know 0 <= location < Int.max, so
//       `Int.max - location` cannot overflow.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct NSRangeToolsTests {

    // MARK: - Sanity: assumptions the source relies on

    @Test func nsNotFoundEqualsIntMax() {
        // The source treats NSNotFound as a sentinel; it is defined as Int.max.
        #expect(NSNotFound == Int.max)
    }

    @Test func nsRangeFieldsAreInt() {
        // The overflow guard `Int.max - location` depends on location/length
        // being Int. Confirm the field types so the boundary math is meaningful.
        let r = NSRange(location: 1, length: 2)
        #expect(type(of: r.location) == Int.self)
        #expect(type(of: r.length) == Int.self)
    }

    // MARK: - Happy path / representative valid ranges

    @Test func typicalValidRangeIsValid() {
        #expect(NSRange(location: 0, length: 0).isValid)
        #expect(NSRange(location: 0, length: 1).isValid)
        #expect(NSRange(location: 5, length: 10).isValid)
        #expect(NSRange(location: 100, length: 0).isValid)
        #expect(NSRange(location: 1, length: 1).isValid)
    }

    @Test func rangeBuiltFromStringIndexIsValid() {
        // A real-world construction path: NSRange of a substring.
        let s = "Hello, world" as NSString
        let r = s.range(of: "world")
        #expect(r.location != NSNotFound)
        #expect(r.isValid)
        // Sanity-check the actual indices Foundation returned.
        #expect(r.location == 7)
        #expect(r.length == 5)
    }

    @Test func rangeFromUnicodeStringIsValid() {
        // NSString uses UTF-16 code unit offsets; multi-code-unit characters
        // (emoji, combining marks) must still yield a valid range.
        let s = "a😀b" as NSString
        let r = s.range(of: "b")
        #expect(r.location != NSNotFound)
        #expect(r.isValid)
        // "😀" is a surrogate pair (2 UTF-16 units), so "b" is at offset 3.
        #expect(r.location == 3)
        #expect(r.length == 1)

        let whole = NSRange(location: 0, length: s.length)
        #expect(whole.isValid)
        #expect(s.length == 4)
    }

    // Pass NSRange values directly: avoids any ambiguity in how Swift Testing
    // maps a single array of tuples onto a multi-parameter test function.
    @Test(arguments: [
        NSRange(location: 0, length: 0),
        NSRange(location: 0, length: 1),
        NSRange(location: 1, length: 0),
        NSRange(location: 7, length: 3),
        NSRange(location: 1_000, length: 999_999),
        NSRange(location: 1, length: Int.max - 1),       // location + length == Int.max exactly
        NSRange(location: 0, length: Int.max),           // boundary: length == Int.max - 0
        NSRange(location: Int.max - 1, length: 1),       // boundary: location + length == Int.max
        NSRange(location: Int.max - 1, length: 0),       // location just below sentinel
    ])
    func validRanges(_ range: NSRange) {
        #expect(range.isValid)
    }

    // MARK: - Invalid: negative location

    @Test(arguments: [-1, -2, -100, Int.min, Int.min + 1])
    func negativeLocationIsInvalid(_ location: Int) {
        #expect(!NSRange(location: location, length: 0).isValid)
        #expect(!NSRange(location: location, length: 5).isValid)
    }

    // MARK: - Invalid: negative length

    @Test(arguments: [-1, -2, -100, Int.min, Int.min + 1])
    func negativeLengthIsInvalid(_ length: Int) {
        #expect(!NSRange(location: 0, length: length).isValid)
        #expect(!NSRange(location: 10, length: length).isValid)
    }

    @Test func bothNegativeIsInvalid() {
        #expect(!NSRange(location: -1, length: -1).isValid)
        #expect(!NSRange(location: Int.min, length: Int.min).isValid)
        #expect(!NSRange(location: Int.min, length: -1).isValid)
        #expect(!NSRange(location: -1, length: Int.min).isValid)
    }

    // MARK: - Invalid: NSNotFound sentinel for location

    @Test func locationEqualToNSNotFoundIsInvalid() {
        // Even with length 0, NSNotFound location is rejected.
        #expect(!NSRange(location: NSNotFound, length: 0).isValid)
        #expect(!NSRange(location: Int.max, length: 0).isValid)
    }

    @Test func notFoundRangeFromStringSearchIsInvalid() {
        // Foundation returns {NSNotFound, 0} when not found.
        let s = "abc" as NSString
        let r = s.range(of: "xyz")
        #expect(r.location == NSNotFound)
        #expect(r.length == 0)
        #expect(!r.isValid)
    }

    // MARK: - Overflow boundary on location + length

    @Test func sumOverflowsIsInvalid() {
        // location + length would exceed Int.max -> invalid.
        #expect(!NSRange(location: 1, length: Int.max).isValid)          // 1 + Int.max overflows
        #expect(!NSRange(location: 2, length: Int.max - 1).isValid)      // sum == Int.max + 1
        #expect(!NSRange(location: Int.max - 1, length: 2).isValid)      // sum == Int.max + 1
        #expect(!NSRange(location: 100, length: Int.max - 50).isValid)   // clear overflow
        #expect(!NSRange(location: Int.max - 1, length: Int.max - 1).isValid)
    }

    @Test func sumExactlyIntMaxIsValid() {
        // The boundary is inclusive: length <= Int.max - location, so a sum of
        // exactly Int.max is permitted.
        #expect(NSRange(location: 1, length: Int.max - 1).isValid)
        #expect(NSRange(location: Int.max - 1, length: 1).isValid)
        #expect(NSRange(location: 0, length: Int.max).isValid)
        #expect(NSRange(location: 2, length: Int.max - 2).isValid)
    }

    @Test func sumOneOverIntMaxIsInvalid() {
        // One past the inclusive boundary must be rejected.
        #expect(!NSRange(location: 1, length: Int.max).isValid)          // sum would be Int.max + 1
        #expect(!NSRange(location: 2, length: Int.max - 1).isValid)      // sum would be Int.max + 1
        #expect(!NSRange(location: 3, length: Int.max - 2).isValid)      // sum would be Int.max + 1
    }

    // The boundary is exactly at length == Int.max - location: one below is
    // valid, the boundary itself is valid, one above is invalid.
    @Test(arguments: [0, 1, 2, 100, 1_000, Int.max - 2])
    func boundaryAroundIntMaxIsExactlyInclusive(_ location: Int) {
        let maxLength = Int.max - location
        #expect(NSRange(location: location, length: maxLength - 1).isValid)
        #expect(NSRange(location: location, length: maxLength).isValid)
        // maxLength + 1 may itself overflow for location == 0; guard it.
        if maxLength < Int.max {
            #expect(!NSRange(location: location, length: maxLength + 1).isValid)
        }
    }

    // MARK: - Precedence interplay: NSNotFound vs overflow guard

    @Test func locationIntMaxWithPositiveLengthIsInvalidWithoutOverflowCrash() {
        // location == Int.max == NSNotFound fails the sentinel check first
        // (short-circuit), so the overflow term is never evaluated and we must
        // not crash even though Int.max + length would overflow.
        #expect(!NSRange(location: Int.max, length: 1).isValid)
        #expect(!NSRange(location: Int.max, length: Int.max).isValid)
        #expect(!NSRange(location: NSNotFound, length: 10).isValid)
    }

    // MARK: - Mutation round-trip (set -> read via isValid)

    @Test func mutatingFieldsTogglesValidity() {
        var r = NSRange(location: 0, length: 0)
        #expect(r.isValid)

        r.location = NSNotFound
        #expect(!r.isValid)

        r.location = 5
        #expect(r.isValid)

        r.length = -1
        #expect(!r.isValid)

        r.length = 3
        #expect(r.isValid)

        r.location = -10
        #expect(!r.isValid)
    }

    @Test func valueSemanticsCopyIsIndependent() {
        // NSRange is a value type; mutating a copy must not affect the original
        // or its reported validity.
        let original = NSRange(location: 5, length: 10)
        var copy = original
        copy.location = NSNotFound
        #expect(original.isValid)
        #expect(!copy.isValid)
        #expect(original.location == 5)
        #expect(original.length == 10)
    }

    // MARK: - Cross-check against a reference reimplementation (exhaustive over edge values)

    /// Independent reference for the documented semantics.
    private func referenceIsValid(location: Int, length: Int) -> Bool {
        guard location >= 0, location != NSNotFound, length >= 0 else { return false }
        // location is in [0, Int.max - 1] here, so Int.max - location is safe.
        return length <= Int.max - location
    }

    @Test func matchesReferenceAcrossEdgeMatrix() {
        let edgeValues: [Int] = [
            Int.min, Int.min + 1, -2, -1, 0, 1, 2, 3,
            100, 1_000, Int.max - 2, Int.max - 1, Int.max,
        ]
        for loc in edgeValues {
            for len in edgeValues {
                let actual = NSRange(location: loc, length: len).isValid
                let expected = referenceIsValid(location: loc, length: len)
                #expect(actual == expected, "loc=\(loc) len=\(len): got \(actual), expected \(expected)")
            }
        }
    }

    // MARK: - Concurrency: isValid is a pure read; hammer it from many tasks

    @Test func concurrentReadsAreConsistent() async {
        // NSRange is a Sendable value type; capturing copies into tasks is safe.
        let validRange = NSRange(location: 5, length: 10)
        let invalidRange = NSRange(location: NSNotFound, length: 0)

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for i in 0..<1_000 {
                group.addTask {
                    // Alternate the two ranges; the invariant is that each range
                    // always reports the same validity regardless of concurrency.
                    if i % 2 == 0 {
                        return validRange.isValid
                    } else {
                        return !invalidRange.isValid
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

    // MARK: - Large data: build many ranges and verify no spurious failures

    @Test func largeSweepOfValidRanges() {
        // 100_000 ranges, all valid by construction; should all report true.
        var trueCount = 0
        for location in stride(from: 0, to: 100_000, by: 1) {
            // length kept modest so location + length never overflows.
            let r = NSRange(location: location, length: location % 7)
            if r.isValid { trueCount += 1 }
        }
        #expect(trueCount == 100_000)
    }

    @Test func largeSweepOfInvalidRangesByNegativeLength() {
        // Mirror image: every range here is invalid (negative length), so none
        // should report valid. Guards against an accidentally always-true property.
        var validCount = 0
        for location in stride(from: 0, to: 100_000, by: 1) {
            let r = NSRange(location: location, length: -(1 + location % 7))
            if r.isValid { validCount += 1 }
        }
        #expect(validCount == 0)
    }
}
