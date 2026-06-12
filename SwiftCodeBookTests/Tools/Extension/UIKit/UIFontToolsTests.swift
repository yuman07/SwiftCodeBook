//
//  UIFontToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIFont+Tools.swift
//  Exercises the public UIFont extension API:
//    - addingTraits(_:)       — unions the given symbolic traits onto the font
//    - removingTraits(_:)     — subtracts the given symbolic traits from the font
//    - containsAllTraits(_:)  — reports whether all given traits are present
//
//  The source uses `fontDescriptor.withSymbolicTraits(...)` which can legitimately
//  fail to synthesize a descriptor for some trait combinations and return `self`
//  unchanged (the guard-let fallback). Tests therefore assert the *documented
//  invariant* — that `containsAllTraits` always agrees with the descriptor's own
//  reported `symbolicTraits` — rather than assuming synthesis always succeeds.
//  This keeps the suite deterministic for traits like expanded/condensed.
//
//  Coverage: happy paths (bold / italic / bold+italic), pointSize & family
//  preservation across add/remove, idempotency, preservation of pre-existing
//  traits, removal no-ops, add->remove round-trips, the "all-or-nothing"
//  semantics of containsAllTraits, intrinsically-bold fonts, non-system fonts,
//  boundary point sizes, and genuine concurrency stress (UIFont is Sendable and
//  these methods are non-isolated, so the stress tasks run off the main actor).
//

import Foundation
import Testing
import UIKit
@testable import SwiftCodeBook

@MainActor
@Suite struct UIFontToolsTests {

    // MARK: - Helpers

    private static let baseSize: CGFloat = 17

    private func makeBase() -> UIFont {
        UIFont.systemFont(ofSize: Self.baseSize)
    }

    /// True iff the source synthesized a descriptor carrying `trait`. When the
    /// platform cannot synthesize it, `addingTraits` returns `self` unchanged and
    /// this is false — letting tests stay robust against the guard-let fallback.
    private func descriptorContains(
        _ font: UIFont,
        _ trait: UIFontDescriptor.SymbolicTraits
    ) -> Bool {
        font.fontDescriptor.symbolicTraits.contains(trait)
    }

    // MARK: - addingTraits: happy path

    @Test func addingBoldProducesBoldTrait() {
        let base = makeBase()
        let bold = base.addingTraits(.traitBold)
        #expect(bold.fontDescriptor.symbolicTraits.contains(.traitBold))
        #expect(bold.containsAllTraits(.traitBold))
    }

    @Test func addingItalicProducesItalicTrait() {
        let base = makeBase()
        let italic = base.addingTraits(.traitItalic)
        #expect(italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        #expect(italic.containsAllTraits(.traitItalic))
    }

    @Test func addingBoldAndItalicProducesBothTraits() {
        let base = makeBase()
        let boldItalic = base.addingTraits([.traitBold, .traitItalic])
        #expect(boldItalic.containsAllTraits([.traitBold, .traitItalic]))
        #expect(boldItalic.containsAllTraits(.traitBold))
        #expect(boldItalic.containsAllTraits(.traitItalic))
    }

    @Test func addingTraitsPreservesPointSize() {
        let base = makeBase()
        let bold = base.addingTraits(.traitBold)
        #expect(bold.pointSize == Self.baseSize)
    }

    @Test func addingTraitsPreservesFontFamily() {
        let base = makeBase()
        let bold = base.addingTraits(.traitBold)
        // Same underlying family, just a bolder variant.
        #expect(bold.familyName == base.familyName)
    }

    @Test func addingEmptyTraitsIsNoOpForTraits() {
        let base = makeBase()
        let result = base.addingTraits([])
        #expect(result.pointSize == base.pointSize)
        // Adding the empty set must not introduce any trait the base lacked,
        // and must keep the same family.
        #expect(result.fontDescriptor.symbolicTraits == base.fontDescriptor.symbolicTraits)
        #expect(result.familyName == base.familyName)
    }

    @Test func addingBoldTwiceIsIdempotentOnTraits() {
        let base = makeBase()
        let once = base.addingTraits(.traitBold)
        let twice = once.addingTraits(.traitBold)
        #expect(twice.containsAllTraits(.traitBold))
        #expect(twice.fontDescriptor.symbolicTraits.contains(.traitBold))
        // Trait set should be stable across repeated adds.
        #expect(twice.fontDescriptor.symbolicTraits == once.fontDescriptor.symbolicTraits)
        #expect(twice.pointSize == once.pointSize)
    }

    @Test func addingTraitsKeepsPreexistingTraits() {
        let base = makeBase()
        let bold = base.addingTraits(.traitBold)
        let boldItalic = bold.addingTraits(.traitItalic)
        // The previously-added bold trait must still be present.
        #expect(boldItalic.containsAllTraits(.traitBold))
        #expect(boldItalic.containsAllTraits(.traitItalic))
        #expect(boldItalic.pointSize == Self.baseSize)
    }

    // MARK: - removingTraits: happy path

    @Test func removingBoldFromBoldClearsTrait() {
        let bold = makeBase().addingTraits(.traitBold)
        #expect(bold.containsAllTraits(.traitBold))
        let plain = bold.removingTraits(.traitBold)
        #expect(!plain.containsAllTraits(.traitBold))
        #expect(!plain.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test func removingItalicFromBoldItalicKeepsBold() {
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        let boldOnly = boldItalic.removingTraits(.traitItalic)
        #expect(boldOnly.containsAllTraits(.traitBold))
        #expect(!boldOnly.containsAllTraits(.traitItalic))
    }

    @Test func removingTraitPreservesPointSize() {
        let bold = makeBase().addingTraits(.traitBold)
        let plain = bold.removingTraits(.traitBold)
        #expect(plain.pointSize == Self.baseSize)
    }

    @Test func removingTraitPreservesFontFamily() {
        let base = makeBase()
        let bold = base.addingTraits(.traitBold)
        let plain = bold.removingTraits(.traitBold)
        #expect(plain.familyName == base.familyName)
    }

    @Test func removingTraitNotPresentIsNoOp() {
        let base = makeBase()
        // Base system font has no italic trait; removing it should change nothing.
        let result = base.removingTraits(.traitItalic)
        #expect(result.fontDescriptor.symbolicTraits == base.fontDescriptor.symbolicTraits)
        #expect(result.pointSize == base.pointSize)
    }

    @Test func removingEmptyTraitsIsNoOp() {
        let bold = makeBase().addingTraits(.traitBold)
        let result = bold.removingTraits([])
        #expect(result.fontDescriptor.symbolicTraits == bold.fontDescriptor.symbolicTraits)
        #expect(result.containsAllTraits(.traitBold))
    }

    @Test func removingBothTraitsClearsBoth() {
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        let cleared = boldItalic.removingTraits([.traitBold, .traitItalic])
        #expect(!cleared.containsAllTraits(.traitBold))
        #expect(!cleared.containsAllTraits(.traitItalic))
    }

    @Test func removingSupersetOnlyClearsPresentTrait() {
        // Only bold is present. Removing {bold, italic} must clear bold and leave
        // the (already-absent) italic absent — i.e. removal is a set subtraction.
        let bold = makeBase().addingTraits(.traitBold)
        let cleared = bold.removingTraits([.traitBold, .traitItalic])
        #expect(!cleared.containsAllTraits(.traitBold))
        #expect(!cleared.containsAllTraits(.traitItalic))
        #expect(cleared.pointSize == Self.baseSize)
    }

    // MARK: - Round trips

    @Test func addThenRemoveBoldRoundTripsTraits() {
        let base = makeBase()
        let roundTripped = base.addingTraits(.traitBold).removingTraits(.traitBold)
        // The bold trait should be gone again, matching the original trait set.
        #expect(roundTripped.fontDescriptor.symbolicTraits == base.fontDescriptor.symbolicTraits)
        #expect(roundTripped.pointSize == base.pointSize)
        #expect(roundTripped.familyName == base.familyName)
    }

    @Test func addThenRemoveBoldItalicRoundTripsTraits() {
        let base = makeBase()
        let roundTripped = base
            .addingTraits([.traitBold, .traitItalic])
            .removingTraits([.traitBold, .traitItalic])
        #expect(!roundTripped.containsAllTraits(.traitBold))
        #expect(!roundTripped.containsAllTraits(.traitItalic))
        #expect(roundTripped.pointSize == base.pointSize)
    }

    // MARK: - containsAllTraits semantics

    @Test func containsAllTraitsTrueWhenAllPresent() {
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        #expect(boldItalic.containsAllTraits([.traitBold, .traitItalic]))
    }

    @Test func containsAllTraitsFalseWhenOnlyOnePresent() {
        // Only bold present; querying for bold+italic must be false (all-or-nothing).
        let bold = makeBase().addingTraits(.traitBold)
        #expect(!bold.containsAllTraits([.traitBold, .traitItalic]))
    }

    @Test func containsAllTraitsTrueForEmptyQuery() {
        // The empty set is a subset of any set, so contains([]) is always true.
        let base = makeBase()
        #expect(base.containsAllTraits([]))
        let bold = base.addingTraits(.traitBold)
        #expect(bold.containsAllTraits([]))
    }

    @Test func containsAllTraitsFalseForPlainFont() {
        let base = makeBase()
        #expect(!base.containsAllTraits(.traitBold))
        #expect(!base.containsAllTraits(.traitItalic))
    }

    @Test func containsAllTraitsSingleSubsetOfMany() {
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        // A single trait that is part of a larger present set must be reported true.
        #expect(boldItalic.containsAllTraits(.traitBold))
        #expect(boldItalic.containsAllTraits(.traitItalic))
    }

    @Test func containsAllTraitsMatchesDescriptorSetExactly() {
        // containsAllTraits is exactly Set.contains(_:) against the descriptor's traits.
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        let traits = boldItalic.fontDescriptor.symbolicTraits
        // The descriptor's own full set is trivially a subset of itself.
        #expect(boldItalic.containsAllTraits(traits))
    }

    // MARK: - Parameterized over individual traits

    // Sendable raw-value arguments; we reconstruct SymbolicTraits inside the body.
    @Test(arguments: [
        UIFontDescriptor.SymbolicTraits.traitBold.rawValue,
        UIFontDescriptor.SymbolicTraits.traitItalic.rawValue,
        UIFontDescriptor.SymbolicTraits.traitExpanded.rawValue,
        UIFontDescriptor.SymbolicTraits.traitCondensed.rawValue,
    ])
    func addingThenContainsIsConsistent(rawTrait: UInt32) {
        let trait = UIFontDescriptor.SymbolicTraits(rawValue: rawTrait)
        let base = makeBase()
        let modified = base.addingTraits(trait)
        // addingTraits may legitimately fail to synthesize a descriptor for some
        // traits and return `self` unchanged. Assert the documented invariant:
        // containsAllTraits agrees with the descriptor's actual reported traits.
        let reported = descriptorContains(modified, trait)
        #expect(modified.containsAllTraits(trait) == reported)
        // Whatever happened to traits, the size must be preserved on both paths.
        #expect(modified.pointSize == Self.baseSize)
        // Removing the same trait must end with the descriptor no longer reporting it.
        let removed = modified.removingTraits(trait)
        #expect(removed.containsAllTraits(trait) == descriptorContains(removed, trait))
        #expect(!descriptorContains(removed, trait))
    }

    // MARK: - Various base sizes (boundaries)

    @Test(arguments: [CGFloat(1), CGFloat(8), CGFloat(12), CGFloat(40), CGFloat(120), CGFloat(0.5)])
    func addingTraitsPreservesArbitrarySize(size: CGFloat) {
        let base = UIFont.systemFont(ofSize: size)
        let bold = base.addingTraits(.traitBold)
        #expect(bold.pointSize == size)
        let back = bold.removingTraits(.traitBold)
        #expect(back.pointSize == size)
    }

    // MARK: - Non-system fonts

    @Test func worksOnPreferredBodyFont() {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let bold = body.addingTraits(.traitBold)
        #expect(bold.pointSize == body.pointSize)
        // containsAllTraits must always agree with the descriptor, synthesized or not.
        #expect(bold.containsAllTraits(.traitBold) == descriptorContains(bold, .traitBold))
    }

    @Test func boldSystemFontAlreadyContainsBold() {
        let bold = UIFont.boldSystemFont(ofSize: Self.baseSize)
        // A font that is already bold should report the bold trait.
        #expect(bold.containsAllTraits(.traitBold))
        // Removing bold from an already-bold font should drop the trait.
        let plain = bold.removingTraits(.traitBold)
        #expect(!plain.containsAllTraits(.traitBold))
        #expect(plain.pointSize == Self.baseSize)
    }

    @Test func addingItalicToIntrinsicallyBoldFontKeepsBold() {
        // Start from an intrinsically-bold font and add italic on top.
        let bold = UIFont.boldSystemFont(ofSize: Self.baseSize)
        #expect(bold.containsAllTraits(.traitBold))
        let boldItalic = bold.addingTraits(.traitItalic)
        // Bold must survive; italic agreement is asserted against the descriptor
        // so the test stays robust if synthesis declines to add italic.
        #expect(boldItalic.containsAllTraits(.traitBold))
        #expect(boldItalic.containsAllTraits(.traitItalic) == descriptorContains(boldItalic, .traitItalic))
        #expect(boldItalic.pointSize == Self.baseSize)
    }

    @Test func italicSystemFontHandledConsistently() {
        // UIFont.italicSystemFont is intrinsically italic; round-trip via the API.
        let italic = UIFont.italicSystemFont(ofSize: Self.baseSize)
        #expect(italic.containsAllTraits(.traitItalic))
        let removed = italic.removingTraits(.traitItalic)
        #expect(!removed.containsAllTraits(.traitItalic))
        #expect(removed.pointSize == Self.baseSize)
    }

    // MARK: - Concurrency
    //
    // UIFont is Sendable and the three methods are non-isolated pure value
    // operations, so the stress tasks intentionally run OFF the main actor to
    // get genuine parallelism. Inputs are created on the main actor first and
    // captured by value; results are reduced deterministically.

    @Test func concurrentTraitOperationsAreConsistent() async {
        let base = makeBase()
        let size = base.pointSize
        let iterations = 500

        let failures = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for i in 0..<iterations {
                let traits: UIFontDescriptor.SymbolicTraits =
                    i.isMultiple(of: 2) ? .traitBold : [.traitBold, .traitItalic]
                group.addTask {
                    let modified = base.addingTraits(traits)
                    let sizeOK = modified.pointSize == size
                    // Whatever traits the descriptor ended up with, containsAllTraits
                    // must agree with the descriptor's own report for those traits.
                    let consistent = modified.containsAllTraits(traits)
                        == modified.fontDescriptor.symbolicTraits.contains(traits)
                    return sizeOK && consistent
                }
            }
            var failed = 0
            for await ok in group where !ok { failed += 1 }
            return failed
        }

        #expect(failures == 0)
    }

    @Test func concurrentReadsOnSharedFontDoNotCrash() async {
        let boldItalic = makeBase().addingTraits([.traitBold, .traitItalic])
        let iterations = 1000

        let agree = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    boldItalic.containsAllTraits(.traitBold)
                        && boldItalic.containsAllTraits(.traitItalic)
                        && boldItalic.containsAllTraits([.traitBold, .traitItalic])
                }
            }
            var count = 0
            for await ok in group where ok { count += 1 }
            return count
        }

        // Every concurrent read must observe the stable, fully-populated trait set.
        #expect(agree == iterations)
    }

    @Test func concurrentRoundTripsArePure() async {
        // Many parallel add->remove round-trips must each return to the original
        // trait set with the original size — proving the API is a pure function.
        let base = makeBase()
        let originalTraits = base.fontDescriptor.symbolicTraits
        let size = base.pointSize
        let iterations = 500

        let mismatches = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    let rt = base.addingTraits(.traitBold).removingTraits(.traitBold)
                    return rt.fontDescriptor.symbolicTraits == originalTraits
                        && rt.pointSize == size
                }
            }
            var bad = 0
            for await ok in group where !ok { bad += 1 }
            return bad
        }

        #expect(mismatches == 0)
    }
}
