//
//  HashHandlerTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Foundation/HashHandler.swift
//  Exercises HashHandler (instance update/finalize/reset), the static
//  hash(data:) / hash(string:) / hash(filePath:) helpers, and the
//  String/Data `hash(using:)` conveniences. Hash outputs are validated
//  against canonical RFC test vectors and cross-checked for internal
//  consistency. Concurrency safety of the thread-safe HashHandler is
//  hammered via task groups, and the async file-hashing path is covered
//  including its cancellation behavior.
//

import Foundation
import Testing
@testable import SwiftCodeBook

@Suite struct HashHandlerTests {

    // MARK: - Canonical reference vectors

    // Reference outputs for the ASCII string "abc" across all algorithms,
    // computed independently with the `md5` / `shasum` CLI tools.
    private static let abcVectors: [(HashHandler.Algorithm, String)] = [
        (.md5, "900150983cd24fb0d6963f7d28e17f72"),
        (.sha1, "a9993e364706816aba3e25717850c26c9cd0d89d"),
        (.sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
        (.sha384, "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"),
        (.sha512, "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"),
    ]

    // Reference outputs for the empty input across all algorithms.
    private static let emptyVectors: [(HashHandler.Algorithm, String)] = [
        (.md5, "d41d8cd98f00b204e9800998ecf8427e"),
        (.sha1, "da39a3ee5e6b4b0d3255bfef95601890afd80709"),
        (.sha256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        (.sha384, "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"),
        (.sha512, "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"),
    ]

    private static let allAlgorithms: [HashHandler.Algorithm] =
        [.md5, .sha1, .sha256, .sha384, .sha512]

    // Expected hex length (number of characters) per algorithm = bytes * 2.
    private static func expectedHexLength(_ algo: HashHandler.Algorithm) -> Int {
        switch algo {
        case .md5: return 32
        case .sha1: return 40
        case .sha256: return 64
        case .sha384: return 96
        case .sha512: return 128
        }
    }

    private static let allowedHexDigits = Set("0123456789abcdef")

    // MARK: - Static hash(string:) against canonical vectors

    @Test(arguments: abcVectors)
    func staticHashStringMatchesAbcVector(algo: HashHandler.Algorithm, expected: String) {
        #expect(HashHandler.hash(string: "abc", using: algo) == expected)
    }

    @Test(arguments: emptyVectors)
    func staticHashStringMatchesEmptyVector(algo: HashHandler.Algorithm, expected: String) {
        #expect(HashHandler.hash(string: "", using: algo) == expected)
    }

    // MARK: - Static hash(data:) against canonical vectors

    @Test(arguments: abcVectors)
    func staticHashDataMatchesAbcVector(algo: HashHandler.Algorithm, expected: String) {
        let data = Data("abc".utf8)
        #expect(HashHandler.hash(data: data, using: algo) == expected)
    }

    @Test(arguments: emptyVectors)
    func staticHashDataEmptyMatchesEmptyVector(algo: HashHandler.Algorithm, expected: String) {
        #expect(HashHandler.hash(data: Data(), using: algo) == expected)
    }

    // hash(string:) must be exactly equivalent to hash(data:) of its UTF-8 bytes.
    @Test(arguments: allAlgorithms)
    func staticHashStringEqualsHashOfUTF8Data(algo: HashHandler.Algorithm) {
        let s = "The quick brown fox jumps over the lazy dog"
        let fromString = HashHandler.hash(string: s, using: algo)
        let fromData = HashHandler.hash(data: Data(s.utf8), using: algo)
        #expect(fromString == fromData)
    }

    // MARK: - Output format invariants

    @Test(arguments: allAlgorithms)
    func outputIsLowercaseHexOfExpectedLength(algo: HashHandler.Algorithm) {
        let out = HashHandler.hash(string: "format-check", using: algo)
        #expect(out.count == Self.expectedHexLength(algo))
        // Only lowercase hex digits are produced by the "%02x" formatting.
        #expect(out.allSatisfy { Self.allowedHexDigits.contains($0) })
        #expect(out == out.lowercased())
    }

    @Test(arguments: allAlgorithms)
    func emptyHashHasExpectedLength(algo: HashHandler.Algorithm) {
        let out = HashHandler.hash(data: Data(), using: algo)
        #expect(out.count == Self.expectedHexLength(algo))
        #expect(out.allSatisfy { Self.allowedHexDigits.contains($0) })
    }

    // Every byte value 0...255 must be preserved verbatim: a single NUL byte and
    // a single 0xFF byte must produce distinct, fixed-length, all-hex digests.
    @Test(arguments: allAlgorithms)
    func binaryBytesAreHashedFaithfully(algo: HashHandler.Algorithm) {
        let nul = HashHandler.hash(data: Data([0x00]), using: algo)
        let high = HashHandler.hash(data: Data([0xFF]), using: algo)
        #expect(nul != high)
        #expect(nul.count == Self.expectedHexLength(algo))
        #expect(high.count == Self.expectedHexLength(algo))
        // A single NUL byte is NOT the same as the empty input.
        #expect(nul != HashHandler.hash(data: Data(), using: algo))
        // Full 0...255 byte range round-trips through Data and hashes to all-hex.
        let allBytes = Data((0...255).map { UInt8($0) })
        let full = HashHandler.hash(data: allBytes, using: algo)
        #expect(full.count == Self.expectedHexLength(algo))
        #expect(full.allSatisfy { Self.allowedHexDigits.contains($0) })
    }

    // MARK: - Determinism and collision-avoidance

    @Test(arguments: allAlgorithms)
    func sameInputProducesSameHash(algo: HashHandler.Algorithm) {
        let a = HashHandler.hash(string: "deterministic", using: algo)
        let b = HashHandler.hash(string: "deterministic", using: algo)
        #expect(a == b)
    }

    @Test(arguments: allAlgorithms)
    func differentInputsProduceDifferentHashes(algo: HashHandler.Algorithm) {
        let a = HashHandler.hash(string: "input-A", using: algo)
        let b = HashHandler.hash(string: "input-B", using: algo)
        #expect(a != b)
    }

    // A single-bit/single-char difference should change the digest (avalanche).
    @Test(arguments: allAlgorithms)
    func smallChangeChangesDigest(algo: HashHandler.Algorithm) {
        let a = HashHandler.hash(string: "message0", using: algo)
        let b = HashHandler.hash(string: "message1", using: algo)
        #expect(a != b)
    }

    @Test
    func differentAlgorithmsGenerallyDiffer() {
        // sha256 vs sha512 of the same input must differ (different length alone
        // guarantees it, but assert inequality directly too).
        let s = "cross-algo"
        let s256 = HashHandler.hash(string: s, using: .sha256)
        let s512 = HashHandler.hash(string: s, using: .sha512)
        #expect(s256 != s512)
        #expect(s256.count != s512.count)
    }

    // Every algorithm produces a distinct digest for the same input. With five
    // algorithms producing five distinct lengths this is guaranteed, but assert
    // pairwise distinctness directly across the whole set.
    @Test
    func allAlgorithmsProduceDistinctDigestsForSameInput() {
        let digests = Self.allAlgorithms.map { HashHandler.hash(string: "same-input", using: $0) }
        #expect(Set(digests).count == Self.allAlgorithms.count)
    }

    // MARK: - Unicode / emoji / combining characters

    @Test(arguments: allAlgorithms)
    func unicodeStringHashesAsItsUTF8(algo: HashHandler.Algorithm) {
        // "é" can be precomposed (U+00E9) or decomposed (U+0065 U+0301).
        // NOTE: Swift String equality is by Unicode canonical equivalence, so
        // `precomposed == decomposed` is TRUE even though their UTF-8 byte
        // representations differ. HashHandler.hash(string:) hashes the actual
        // stored UTF-8 bytes (via Data(string.utf8)), so the two MUST still
        // produce different digests — confirming the function is byte-faithful
        // and not normalizing.
        let precomposed = "\u{00E9}"
        let decomposed = "\u{0065}\u{0301}"
        #expect(precomposed == decomposed) // canonically equivalent Strings
        #expect(Array(precomposed.utf8) != Array(decomposed.utf8)) // but different bytes
        let h1 = HashHandler.hash(string: precomposed, using: algo)
        let h2 = HashHandler.hash(string: decomposed, using: algo)
        #expect(h1 != h2)
        // And each equals the hash of its own UTF-8 byte data.
        #expect(h1 == HashHandler.hash(data: Data(precomposed.utf8), using: algo))
        #expect(h2 == HashHandler.hash(data: Data(decomposed.utf8), using: algo))
    }

    @Test(arguments: allAlgorithms)
    func emojiStringIsHashable(algo: HashHandler.Algorithm) {
        let emoji = "👨‍👩‍👧‍👦🇨🇳🧗🏽‍♀️"
        let out = HashHandler.hash(string: emoji, using: algo)
        #expect(out.count == Self.expectedHexLength(algo))
        #expect(out == HashHandler.hash(data: Data(emoji.utf8), using: algo))
    }

    // MARK: - String / Data convenience extensions

    @Test(arguments: abcVectors)
    func stringHashExtensionMatchesStatic(algo: HashHandler.Algorithm, expected: String) {
        #expect("abc".hash(using: algo) == expected)
        #expect("abc".hash(using: algo) == HashHandler.hash(string: "abc", using: algo))
    }

    @Test(arguments: abcVectors)
    func dataHashExtensionMatchesStatic(algo: HashHandler.Algorithm, expected: String) {
        let data = Data("abc".utf8)
        #expect(data.hash(using: algo) == expected)
        #expect(data.hash(using: algo) == HashHandler.hash(data: data, using: algo))
    }

    @Test(arguments: allAlgorithms)
    func emptyDataExtensionHashes(algo: HashHandler.Algorithm) {
        #expect(Data().hash(using: algo) == HashHandler.hash(data: Data(), using: algo))
        #expect("".hash(using: algo) == HashHandler.hash(string: "", using: algo))
    }

    // MARK: - Instance API: update / finalize

    @Test(arguments: abcVectors)
    func instanceSingleUpdateMatchesVector(algo: HashHandler.Algorithm, expected: String) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("abc".utf8))
        #expect(handler.finalize() == expected)
    }

    @Test(arguments: abcVectors)
    func instanceNoUpdateThenFinalizeIsEmptyVector(algo: HashHandler.Algorithm, expected: String) {
        // finalize with no update == hash of empty input.
        _ = expected // not used; kept to share the arguments shape
        let handler = HashHandler(algorithm: algo)
        let out = handler.finalize()
        #expect(out == HashHandler.hash(data: Data(), using: algo))
    }

    // finalize() is non-mutating on the underlying HashFunction, so calling it
    // twice in a row must return the identical digest (no internal reset).
    @Test(arguments: allAlgorithms)
    func finalizeIsRepeatableWithoutReset(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("repeat-finalize".utf8))
        let first = handler.finalize()
        let second = handler.finalize()
        #expect(first == second)
        #expect(first == HashHandler.hash(string: "repeat-finalize", using: algo))
    }

    // Because finalize() does not reset the running state, updating AFTER a
    // finalize must continue accumulating from where it left off.
    @Test(arguments: allAlgorithms)
    func updateAfterFinalizeContinuesAccumulating(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("part1".utf8))
        _ = handler.finalize() // does not reset
        handler.update(data: Data("part2".utf8))
        #expect(handler.finalize() == HashHandler.hash(string: "part1part2", using: algo))
    }

    // Incremental updates must produce the same digest as one combined update.
    @Test(arguments: allAlgorithms)
    func incrementalUpdatesEqualSingleUpdate(algo: HashHandler.Algorithm) {
        let full = "abcdefghijklmnopqrstuvwxyz0123456789"
        let combined = HashHandler.hash(string: full, using: algo)

        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("abcdefghijklm".utf8))
        handler.update(data: Data("nopqrstuvwxyz".utf8))
        handler.update(data: Data("0123456789".utf8))
        #expect(handler.finalize() == combined)
    }

    @Test(arguments: allAlgorithms)
    func updatingWithEmptyDataDoesNotChangeDigest(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data())
        handler.update(data: Data("payload".utf8))
        handler.update(data: Data())
        #expect(handler.finalize() == HashHandler.hash(string: "payload", using: algo))
    }

    @Test(arguments: allAlgorithms)
    func manyTinyUpdatesEqualSingleUpdate(algo: HashHandler.Algorithm) {
        // Feed byte-by-byte and compare with one shot.
        let bytes = Array("streamed-input-value".utf8)
        let expected = HashHandler.hash(data: Data(bytes), using: algo)

        let handler = HashHandler(algorithm: algo)
        for b in bytes {
            handler.update(data: Data([b]))
        }
        #expect(handler.finalize() == expected)
    }

    // MARK: - Instance API: reset

    @Test(arguments: allAlgorithms)
    func resetBeforeFinalizeProducesEmptyDigest(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("will be discarded".utf8))
        handler.reset()
        #expect(handler.finalize() == HashHandler.hash(data: Data(), using: algo))
    }

    @Test(arguments: allAlgorithms)
    func resetThenReuseProducesCorrectDigest(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("garbage".utf8))
        handler.reset()
        handler.update(data: Data("abc".utf8))
        #expect(handler.finalize() == HashHandler.hash(string: "abc", using: algo))
    }

    @Test(arguments: allAlgorithms)
    func resetWithoutPriorUpdateIsHarmless(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.reset()
        handler.update(data: Data("abc".utf8))
        #expect(handler.finalize() == HashHandler.hash(string: "abc", using: algo))
    }

    // Reset after a finalize must clear accumulated state so the next digest is
    // independent of everything fed before the reset.
    @Test(arguments: allAlgorithms)
    func resetAfterFinalizeClearsState(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("first".utf8))
        _ = handler.finalize()
        handler.reset()
        handler.update(data: Data("second".utf8))
        #expect(handler.finalize() == HashHandler.hash(string: "second", using: algo))
    }

    // Two consecutive resets are equivalent to one.
    @Test(arguments: allAlgorithms)
    func doubleResetIsIdempotent(algo: HashHandler.Algorithm) {
        let handler = HashHandler(algorithm: algo)
        handler.update(data: Data("noise".utf8))
        handler.reset()
        handler.reset()
        handler.update(data: Data("abc".utf8))
        #expect(handler.finalize() == HashHandler.hash(string: "abc", using: algo))
    }

    // The same instance can be reused via reset for multiple independent digests.
    @Test
    func instanceReusableAcrossMultipleResetCycles() {
        let handler = HashHandler(algorithm: .sha256)
        let inputs = ["alpha", "beta", "gamma", ""]
        for input in inputs {
            handler.reset()
            handler.update(data: Data(input.utf8))
            #expect(handler.finalize() == HashHandler.hash(string: input, using: .sha256))
        }
    }

    // MARK: - Large data

    @Test(arguments: allAlgorithms)
    func largeDataHashIsConsistentBetweenStaticAndInstance(algo: HashHandler.Algorithm) {
        // 100_000 bytes of a repeating pattern.
        let big = Data((0..<100_000).map { UInt8($0 & 0xFF) })
        let staticOut = HashHandler.hash(data: big, using: algo)

        // Same data fed in chunks to an instance must agree.
        let handler = HashHandler(algorithm: algo)
        var offset = 0
        let chunk = 4096
        while offset < big.count {
            let end = min(offset + chunk, big.count)
            handler.update(data: big.subdata(in: offset..<end))
            offset = end
        }
        #expect(handler.finalize() == staticOut)
        #expect(staticOut.count == Self.expectedHexLength(algo))
    }

    @Test
    func largeStringHashHasCorrectLength() {
        let s = String(repeating: "Lorem ipsum dolor sit amet. ", count: 5000)
        let out = HashHandler.hash(string: s, using: .sha512)
        #expect(out.count == 128)
        // Deterministic across two calls on a large input.
        #expect(out == HashHandler.hash(string: s, using: .sha512))
    }

    // MARK: - Concurrency: thread-safe instance

    // HashHandler is Sendable and guards its state with OSAllocatedUnfairLock.
    // Hammer one shared instance with many concurrent updates; the final digest
    // must be order-independent because all updates push identical single bytes,
    // and must equal a sequentially computed reference. No crash / no data race.
    @Test
    func concurrentUpdatesOnSharedInstanceAreSafe() async {
        let count = 1000
        let handler = HashHandler(algorithm: .sha256)
        let single = Data([0x41]) // 'A'

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    handler.update(data: single)
                }
            }
            await group.waitForAll()
        }

        // All updates are the same byte, so the cumulative input is "A" * count
        // regardless of interleaving order.
        let expected = HashHandler.hash(data: Data(repeating: 0x41, count: count), using: .sha256)
        #expect(handler.finalize() == expected)
    }

    // Many concurrent independent computations via the static API on a shared
    // algorithm must all return the same correct value (each call uses its own
    // local hasher, so this proves there is no shared mutable state corruption).
    @Test
    func concurrentStaticHashCallsAreConsistent() async {
        let expected = HashHandler.hash(string: "abc", using: .sha256)
        let results = await withTaskGroup(of: String.self, returning: [String].self) { group in
            for _ in 0..<500 {
                group.addTask {
                    HashHandler.hash(string: "abc", using: .sha256)
                }
            }
            var acc: [String] = []
            for await r in group {
                acc.append(r)
            }
            return acc
        }
        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 == expected })
    }

    // Concurrent reset + finalize cycles on separate instances must each be
    // correct (proves per-instance isolation under load).
    @Test
    func concurrentPerInstanceResetCyclesAreSafe() async {
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for i in 0..<200 {
                group.addTask {
                    let h = HashHandler(algorithm: .md5)
                    h.update(data: Data("scratch".utf8))
                    h.reset()
                    let input = "value-\(i)"
                    h.update(data: Data(input.utf8))
                    return h.finalize() == HashHandler.hash(string: input, using: .md5)
                }
            }
            var acc: [Bool] = []
            for await ok in group {
                acc.append(ok)
            }
            return acc
        }
        #expect(results.count == 200)
        #expect(results.allSatisfy { $0 })
    }

    // Interleaving update + finalize across many tasks on one shared instance
    // must never crash or trip a data race; the lock serializes every access.
    @Test
    func concurrentMixedUpdateAndFinalizeNeverCrashes() async {
        let handler = HashHandler(algorithm: .sha512)
        let payload = Data("mix".utf8)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<500 {
                group.addTask {
                    if i.isMultiple(of: 2) {
                        handler.update(data: payload)
                    } else {
                        // Read access through the same lock; result is unused but
                        // the call must be data-race-free and well-formed hex.
                        let digest = handler.finalize()
                        #expect(digest.count == Self.expectedHexLength(.sha512))
                    }
                }
            }
            await group.waitForAll()
        }
        // After all updates land, a final readout is still valid lowercase hex.
        let final = handler.finalize()
        #expect(final.count == Self.expectedHexLength(.sha512))
        #expect(final.allSatisfy { Self.allowedHexDigits.contains($0) })
    }

    // MARK: - Async file hashing: happy path

    @Test(arguments: allAlgorithms)
    func hashFilePathMatchesDataHash(algo: HashHandler.Algorithm) async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let contents = Data("hash me from a file".utf8)
        let fileURL = dir.appendingPathComponent("payload.bin")
        try contents.write(to: fileURL)

        let fileHash = try await HashHandler.hash(filePath: fileURL.path, using: algo)
        #expect(fileHash == HashHandler.hash(data: contents, using: algo))
    }

    @Test
    func hashEmptyFileMatchesEmptyDigest() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("empty.bin")
        try Data().write(to: fileURL)

        let fileHash = try await HashHandler.hash(filePath: fileURL.path, using: .sha256)
        #expect(fileHash == HashHandler.hash(data: Data(), using: .sha256))
    }

    // File larger than the 16384-byte read buffer to force multiple read loops.
    @Test
    func hashLargeFileSpanningMultipleReadChunks() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // ~250 KB, clearly beyond a single 16 KB read.
        let big = Data((0..<250_000).map { UInt8(($0 * 7) & 0xFF) })
        let fileURL = dir.appendingPathComponent("big.bin")
        try big.write(to: fileURL)

        let fileHash = try await HashHandler.hash(filePath: fileURL.path, using: .sha512)
        #expect(fileHash == HashHandler.hash(data: big, using: .sha512))
    }

    // Boundary: a file whose size is exactly the 16384-byte read buffer must hash
    // correctly (the read loop reads one full chunk then an empty terminating read).
    @Test(arguments: allAlgorithms)
    func hashFileExactlyOneBufferLong(algo: HashHandler.Algorithm) async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let exact = Data((0..<16384).map { UInt8($0 & 0xFF) })
        let fileURL = dir.appendingPathComponent("exact-buffer.bin")
        try exact.write(to: fileURL)

        let fileHash = try await HashHandler.hash(filePath: fileURL.path, using: algo)
        #expect(fileHash == HashHandler.hash(data: exact, using: algo))
    }

    @Test
    func hashFileMatchesAbcVector() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("abc.txt")
        try Data("abc".utf8).write(to: fileURL)

        let fileHash = try await HashHandler.hash(filePath: fileURL.path, using: .sha256)
        #expect(fileHash == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: - Async file hashing: error path

    @Test
    func hashNonexistentFileThrows() async {
        let bogus = FileManager.default.temporaryDirectory
            .appendingPathComponent("definitely-missing-\(UUID().uuidString).bin")
            .path
        await #expect(throws: (any Error).self) {
            _ = try await HashHandler.hash(filePath: bogus, using: .sha256)
        }
    }

    // Pointing the reader at a directory (not a regular file) must also throw
    // rather than silently returning a bogus digest.
    @Test
    func hashDirectoryPathThrows() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = dir.path
        await #expect(throws: (any Error).self) {
            _ = try await HashHandler.hash(filePath: path, using: .sha256)
        }
    }

    // MARK: - Async file hashing: cancellation

    // A task cancelled before it runs the body should throw CancellationError
    // (the function calls Task.checkCancellation() up front). Cancelling the task
    // synchronously immediately after construction is deterministic: cooperative
    // scheduling cannot preempt this synchronous code, so the cancellation flag is
    // set before the @concurrent body ever reaches its first checkCancellation().
    @Test
    func hashFilePathHonorsCancellation() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("cancel.bin")
        // Reasonably large so cancellation has a chance to be observed mid-loop too.
        try Data(repeating: 0xAB, count: 2_000_000).write(to: fileURL)

        let path = fileURL.path
        let task = Task {
            try await HashHandler.hash(filePath: path, using: .sha512)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    // MARK: - Algorithm enum sanity

    @Test
    func algorithmCasesAreDistinct() {
        // Each algorithm yields a digest of a unique length for the same input,
        // confirming the enum routes to distinct hash functions.
        let lengths = Set(Self.allAlgorithms.map {
            HashHandler.hash(string: "x", using: $0).count
        })
        #expect(lengths == Set([32, 40, 64, 96, 128]))
    }

    // MARK: - Helpers

    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HashHandlerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
