//
//  DataToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/Data+Tools.swift
//  Covers the public `Data` extension:
//    - func compressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data
//    - func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct DataToolsTests {

    // MARK: - Helpers

    /// All four algorithms Foundation supports for NSData compression.
    private static let allAlgorithms: [NSData.CompressionAlgorithm] = [.lzfse, .lz4, .lzma, .zlib]

    /// All ordered pairs of distinct algorithms, used for cross-algorithm
    /// mismatch coverage (compress with A, attempt decompress with B != A).
    private static var mismatchPairs: [(from: NSData.CompressionAlgorithm, to: NSData.CompressionAlgorithm)] {
        var pairs = [(NSData.CompressionAlgorithm, NSData.CompressionAlgorithm)]()
        for from in allAlgorithms {
            for to in allAlgorithms where from != to {
                pairs.append((from, to))
            }
        }
        return pairs
    }

    /// Compressible payload: highly repetitive data so that for any algorithm
    /// the compressed size is meaningfully smaller than the original.
    private static func compressiblePayload(repeating count: Int) -> Data {
        Data(repeating: 0x41, count: count) // "A" repeated
    }

    /// A realistic, mixed-content payload (still fairly compressible because of
    /// repetition) used for round-trip checks.
    private static func textPayload() -> Data {
        let s = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 200)
        return Data(s.utf8)
    }

    /// Deterministic pseudo-random ("incompressible") payload. Uses a fixed
    /// linear-congruential sequence so the bytes are reproducible across runs
    /// but have no exploitable redundancy. Not for crypto — for test stability.
    private static func incompressiblePayload(count: Int) -> Data {
        var state: UInt64 = 0x2545F4914F6CDD1D
        var bytes = [UInt8]()
        bytes.reserveCapacity(count)
        for _ in 0..<count {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            bytes.append(UInt8(truncatingIfNeeded: state >> 33))
        }
        return Data(bytes)
    }

    // MARK: - Round-trip: compress then decompress yields the original

    @Test(arguments: allAlgorithms)
    func roundTripRestoresOriginal(algorithm: NSData.CompressionAlgorithm) throws {
        let original = Self.textPayload()
        let compressed = try original.compressed(using: algorithm)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
    }

    @Test(arguments: allAlgorithms)
    func roundTripRestoresBinaryPayload(algorithm: NSData.CompressionAlgorithm) throws {
        // A byte ramp 0...255 repeated, exercising the full byte range.
        var bytes = [UInt8]()
        for _ in 0..<400 {
            for b in 0...255 { bytes.append(UInt8(b)) }
        }
        let original = Data(bytes)
        let compressed = try original.compressed(using: algorithm)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
        #expect(restored.count == original.count)
    }

    @Test(arguments: allAlgorithms)
    func roundTripRestoresIncompressiblePayload(algorithm: NSData.CompressionAlgorithm) throws {
        // High-entropy data may compress to >= its original size, but it must
        // still round-trip losslessly. Verified empirically for all four
        // algorithms (compressed size can exceed the original).
        let original = Self.incompressiblePayload(count: 4_096)
        let compressed = try original.compressed(using: algorithm)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
        #expect(restored.count == original.count)
    }

    // MARK: - Compression actually shrinks highly-compressible data

    @Test(arguments: allAlgorithms)
    func compressionShrinksRepetitiveData(algorithm: NSData.CompressionAlgorithm) throws {
        let original = Self.compressiblePayload(repeating: 100_000)
        let compressed = try original.compressed(using: algorithm)
        // 100k identical bytes must compress to far less than the original.
        #expect(compressed.count < original.count)
        // Sanity: it should be dramatically smaller for such trivial data.
        // Verified empirically: worst case (lz4) compresses 100k -> 678 bytes.
        #expect(compressed.count < original.count / 2)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
    }

    // MARK: - Empty data boundary

    @Test(arguments: allAlgorithms)
    func emptyDataCompressionRoundTrips(algorithm: NSData.CompressionAlgorithm) throws {
        // Compressing empty data succeeds (it emits a tiny header-only stream)
        // and round-trips back to empty rather than throwing.
        let empty = Data()
        let compressed = try empty.compressed(using: algorithm)
        // The compressed form of empty input is a non-empty header-only stream.
        #expect(!compressed.isEmpty)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == empty)
        #expect(restored.isEmpty)
    }

    @Test(arguments: allAlgorithms)
    func emptyDataDirectDecompressionThrows(algorithm: NSData.CompressionAlgorithm) {
        // Decompressing raw empty input (with no valid header) is invalid and throws.
        let empty = Data()
        #expect(throws: (any Error).self) {
            _ = try empty.decompressed(using: algorithm)
        }
    }

    // MARK: - Single-byte boundary

    @Test(arguments: allAlgorithms)
    func singleByteRoundTrips(algorithm: NSData.CompressionAlgorithm) throws {
        let original = Data([0xAB])
        let compressed = try original.compressed(using: algorithm)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
        #expect(restored.count == 1)
        let first = try #require(restored.first)
        #expect(first == 0xAB)
    }

    // MARK: - Small-boundary payloads (two-byte, all-zero, all-0xFF)

    @Test(arguments: allAlgorithms)
    func smallBoundaryPayloadsRoundTrip(algorithm: NSData.CompressionAlgorithm) throws {
        let payloads: [Data] = [
            Data([0x00, 0x00]),                  // two zero bytes
            Data([0xFF, 0xFF, 0xFF, 0xFF]),      // all 0xFF
            Data(repeating: 0x00, count: 256),   // a block of zeros
            Data(repeating: 0xFF, count: 256),   // a block of 0xFF
        ]
        for original in payloads {
            let compressed = try original.compressed(using: algorithm)
            let restored = try compressed.decompressed(using: algorithm)
            #expect(restored == original)
            #expect(restored.count == original.count)
        }
    }

    // MARK: - Unicode round-trip (multi-byte scalars must survive byte-for-byte)

    @Test(arguments: allAlgorithms)
    func unicodeRoundTrips(algorithm: NSData.CompressionAlgorithm) throws {
        let s = String(repeating: "héllo 世界 🚀 \u{1F1E8}\u{1F1F3} café naïve ", count: 50)
        let original = Data(s.utf8)
        let compressed = try original.compressed(using: algorithm)
        let restored = try compressed.decompressed(using: algorithm)
        #expect(restored == original)
        // The restored bytes must decode back to the exact same String.
        let restoredString = String(decoding: restored, as: UTF8.self)
        #expect(restoredString == s)
    }

    // MARK: - Decompressing garbage / malformed input throws

    @Test(arguments: allAlgorithms)
    func decompressingGarbageThrows(algorithm: NSData.CompressionAlgorithm) {
        // Random/uncompressed bytes are not a valid compressed stream.
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xAA, 0x55])
        #expect(throws: (any Error).self) {
            _ = try garbage.decompressed(using: algorithm)
        }
    }

    @Test func decompressingPlainTextThrows() {
        // A plausible but invalid stream for zlib.
        let plain = Data("not a compressed stream at all, just plain ASCII text".utf8)
        #expect(throws: (any Error).self) {
            _ = try plain.decompressed(using: .zlib)
        }
    }

    // MARK: - Cross-algorithm mismatch: decompress with the wrong algorithm

    @Test(arguments: mismatchPairs)
    func decompressWithWrongAlgorithmThrows(pair: (from: NSData.CompressionAlgorithm, to: NSData.CompressionAlgorithm)) throws {
        // Compress with `from`, attempt to decompress as a different algorithm
        // `to`. The framed formats differ enough that every one of the 12
        // ordered distinct pairs must fail rather than silently corrupt.
        // Verified empirically: all 12 ordered pairs throw.
        let original = Self.textPayload()
        let compressed = try original.compressed(using: pair.from)
        #expect(throws: (any Error).self) {
            _ = try compressed.decompressed(using: pair.to)
        }
    }

    // MARK: - Determinism: compressing the same input twice is identical

    @Test(arguments: allAlgorithms)
    func compressionIsDeterministic(algorithm: NSData.CompressionAlgorithm) throws {
        let original = Self.textPayload()
        let a = try original.compressed(using: algorithm)
        let b = try original.compressed(using: algorithm)
        #expect(a == b)
    }

    // MARK: - Different algorithms generally yield different bytes

    @Test func allAlgorithmPairsProduceDifferentOutput() throws {
        // Compress one non-trivial payload with every algorithm and assert that
        // every unordered pair of outputs differs. This guards against the
        // algorithm argument being silently ignored. Verified empirically: all
        // 6 unordered pairs differ for repetitive data.
        let original = Self.compressiblePayload(repeating: 10_000)
        var outputs = [Data]()
        for algorithm in Self.allAlgorithms {
            outputs.append(try original.compressed(using: algorithm))
        }
        for i in outputs.indices {
            for j in outputs.indices where j > i {
                #expect(outputs[i] != outputs[j],
                        "algorithms \(Self.allAlgorithms[i]) and \(Self.allAlgorithms[j]) produced identical output")
            }
        }
    }

    // MARK: - Return type is a value-type Data, original is untouched

    @Test func compressingDoesNotMutateOriginal() throws {
        let original = Self.textPayload()
        let copy = original
        _ = try original.compressed(using: .zlib)
        #expect(original == copy)
    }

    @Test func decompressingDoesNotMutateInput() throws {
        let original = Self.textPayload()
        let compressed = try original.compressed(using: .zlib)
        let compressedCopy = compressed
        _ = try compressed.decompressed(using: .zlib)
        #expect(compressed == compressedCopy)
    }

    // MARK: - Result is usable as a normal Data value

    @Test func compressedResultIsIndependentData() throws {
        let original = Self.compressiblePayload(repeating: 1_000)
        var compressed = try original.compressed(using: .lz4)
        let originalCompressedCount = compressed.count
        // Mutating the result must not affect anything else and must remain Data.
        compressed.append(0xFF)
        #expect(compressed.count == originalCompressedCount + 1)
    }

    // MARK: - Large data round-trip (time-bounded)

    @Test func largeDataRoundTrips() throws {
        // 1 MB of semi-repetitive data; bounded and fast.
        var bytes = [UInt8]()
        bytes.reserveCapacity(1_000_000)
        var seed: UInt8 = 7
        for i in 0..<1_000_000 {
            // Mildly varying but compressible pattern.
            seed = seed &+ UInt8(i & 0x0F)
            bytes.append(seed)
        }
        let original = Data(bytes)
        let compressed = try original.compressed(using: .lzfse)
        let restored = try compressed.decompressed(using: .lzfse)
        #expect(restored == original)
        #expect(restored.count == 1_000_000)
    }

    // MARK: - Round-trip through every algorithm preserves cross-equality

    @Test func allAlgorithmsRoundTripSamePayload() throws {
        let original = Self.textPayload()
        for algorithm in Self.allAlgorithms {
            let compressed = try original.compressed(using: algorithm)
            let restored = try compressed.decompressed(using: algorithm)
            #expect(restored == original, "algorithm \(algorithm) failed round-trip")
        }
    }

    // MARK: - Concurrency: hammer compress/decompress from many tasks

    @Test func concurrentRoundTripsAreCorrect() async throws {
        let original = Self.textPayload()
        // Precompute the expected compressed bytes (compression is deterministic).
        let expectedCompressed = try original.compressed(using: .zlib)

        let results: [Bool] = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    do {
                        let c = try original.compressed(using: .zlib)
                        guard c == expectedCompressed else { return false }
                        let r = try c.decompressed(using: .zlib)
                        return r == original
                    } catch {
                        return false
                    }
                }
            }
            var collected = [Bool]()
            for await ok in group { collected.append(ok) }
            return collected
        }

        #expect(results.count == 500)
        #expect(results.allSatisfy { $0 })
    }

    @Test func concurrentMixedAlgorithmsAreCorrect() async throws {
        let original = Self.compressiblePayload(repeating: 2_000)
        let algorithms = Self.allAlgorithms

        // Precompute the deterministic expected compressed output per algorithm
        // so each concurrent task can assert byte-exact reproducibility, not
        // just round-trip correctness.
        var expected = [Int: Data]()
        for (idx, algorithm) in algorithms.enumerated() {
            expected[idx] = try original.compressed(using: algorithm)
        }
        let expectedByIndex = expected

        let allOK: Bool = await withTaskGroup(of: Bool.self) { group in
            for i in 0..<400 {
                let index = i % algorithms.count
                let algorithm = algorithms[index]
                group.addTask {
                    do {
                        let c = try original.compressed(using: algorithm)
                        guard c == expectedByIndex[index] else { return false }
                        let r = try c.decompressed(using: algorithm)
                        return r == original
                    } catch {
                        return false
                    }
                }
            }
            var ok = true
            for await result in group { ok = ok && result }
            return ok
        }

        #expect(allOK)
    }

    @Test(arguments: allAlgorithms)
    func concurrentCompressionIsDeterministic(algorithm: NSData.CompressionAlgorithm) async throws {
        // Many concurrent compressions of the same input must all produce the
        // identical byte stream (no shared-state corruption / data races).
        let original = Self.textPayload()
        let expected = try original.compressed(using: algorithm)

        let allMatch: Bool = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    (try? original.compressed(using: algorithm)) == expected
                }
            }
            var ok = true
            for await match in group { ok = ok && match }
            return ok
        }

        #expect(allMatch)
    }
}
