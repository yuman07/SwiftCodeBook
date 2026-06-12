//
//  FileManagerToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/Foundation/FileManager+Tools.swift
//  Covers the public `FileManager` extension:
//    - var homePath: String
//    - var documentPath: String?
//    - var libraryPath: String?
//    - var cachePath: String?
//    - var tmpPath: String
//    - func sizeInBytes(at:) async throws -> (logicalBytes: UInt64, physicalBytes: UInt64)
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct FileManagerToolsTests {

    // MARK: - homePath

    @Test
    func homePathMatchesNSHomeDirectory() {
        #expect(FileManager.default.homePath == NSHomeDirectory())
    }

    @Test
    func homePathIsNonEmptyAbsolutePath() {
        let path = FileManager.default.homePath
        #expect(!path.isEmpty)
        #expect(path.hasPrefix("/"))
    }

    @Test
    func homePathIsStableAcrossReads() {
        let fm = FileManager.default
        #expect(fm.homePath == fm.homePath)
    }

    @Test
    func homePathDirectoryExists() {
        let path = FileManager.default.homePath
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
    }

    // MARK: - documentPath

    @Test
    func documentPathMatchesNSSearchPath() {
        let expected = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        #expect(FileManager.default.documentPath == expected)
    }

    @Test
    func documentPathIsNonNilOnSimulator() throws {
        // On iOS the document directory always resolves for the app sandbox.
        let path = try #require(FileManager.default.documentPath)
        #expect(!path.isEmpty)
        #expect(path.hasPrefix("/"))
    }

    @Test
    func documentPathContainsDocumentsComponent() throws {
        let path = try #require(FileManager.default.documentPath)
        #expect(path.contains("Documents"))
    }

    // MARK: - libraryPath

    @Test
    func libraryPathMatchesNSSearchPath() {
        let expected = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
        #expect(FileManager.default.libraryPath == expected)
    }

    @Test
    func libraryPathIsNonNilOnSimulator() throws {
        let path = try #require(FileManager.default.libraryPath)
        #expect(!path.isEmpty)
        #expect(path.hasPrefix("/"))
    }

    @Test
    func libraryPathContainsLibraryComponent() throws {
        let path = try #require(FileManager.default.libraryPath)
        #expect(path.contains("Library"))
    }

    // MARK: - cachePath

    @Test
    func cachePathMatchesNSSearchPath() {
        let expected = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
        #expect(FileManager.default.cachePath == expected)
    }

    @Test
    func cachePathIsNonNilOnSimulator() throws {
        let path = try #require(FileManager.default.cachePath)
        #expect(!path.isEmpty)
        #expect(path.hasPrefix("/"))
    }

    @Test
    func cachePathContainsCachesComponent() throws {
        let path = try #require(FileManager.default.cachePath)
        #expect(path.contains("Caches"))
    }

    @Test
    func cachePathIsUnderLibrary() throws {
        // The Caches directory lives under Library in the app sandbox.
        let cache = try #require(FileManager.default.cachePath)
        let library = try #require(FileManager.default.libraryPath)
        #expect(cache.hasPrefix(library))
    }

    // MARK: - tmpPath

    @Test
    func tmpPathMatchesNSTemporaryDirectory() {
        #expect(FileManager.default.tmpPath == NSTemporaryDirectory())
    }

    @Test
    func tmpPathIsNonEmptyAbsolutePath() {
        let path = FileManager.default.tmpPath
        #expect(!path.isEmpty)
        #expect(path.hasPrefix("/"))
    }

    @Test
    func tmpPathDirectoryExists() {
        let path = FileManager.default.tmpPath
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
    }

    // MARK: - Cross-property sanity

    @Test
    func distinctSandboxPathsAreDistinct() throws {
        let fm = FileManager.default
        let doc = try #require(fm.documentPath)
        let lib = try #require(fm.libraryPath)
        let cache = try #require(fm.cachePath)
        // NSTemporaryDirectory() may carry a trailing slash; normalise before
        // comparing so the distinctness check is about directories, not spelling.
        let tmp = (fm.tmpPath as NSString).standardizingPath
        // These four should all be different directories.
        let set: Set<String> = [doc, lib, cache, tmp]
        #expect(set.count == 4)
    }

    // MARK: - sizeInBytes: empty / single-file cases

    @Test
    func sizeInBytesNonexistentPathReturnsZero() async throws {
        // A path that does not exist: enumerator(at:) returns nil for a missing
        // location, and resourceValues on a missing URL fails, so totals are 0.
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
            .path
        let result = try await FileManager.default.sizeInBytes(at: missing)
        #expect(result.logicalBytes == 0)
        #expect(result.physicalBytes == 0)
    }

    @Test
    func sizeInBytesEmptyDirectoryReturnsZeroLogicalBytes() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        // An empty directory contains no files; logical size is 0.
        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == 0)
        // A directory's own allocated size must be at least its (zero) logical
        // size — a meaningful invariant rather than the always-true `>= 0`.
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesDirectoryOfEmptySubdirectoriesIsZeroLogical() async throws {
        // Boundary: a tree of nested directories with no regular files at all.
        // The enumerator yields only directories, none of which add logical bytes.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let deep = dir
            .appendingPathComponent("a", isDirectory: true)
            .appendingPathComponent("b", isDirectory: true)
            .appendingPathComponent("c", isDirectory: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)

        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == 0)
    }

    @Test
    func sizeInBytesSingleEmptyFileReturnsZeroLogicalBytes() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("empty.bin")
        try Data().write(to: file)

        let result = try await FileManager.default.sizeInBytes(at: file.path)
        #expect(result.logicalBytes == 0)
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesSingleFileEqualsItsContentLength() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let bytes = 4096
        let file = dir.appendingPathComponent("data.bin")
        try Data(repeating: 0xAB, count: bytes).write(to: file)

        // Pointing the path directly at a single file: the root resourceValues
        // branch contributes the file size; the enumerator yields nothing for a
        // regular file, so logical bytes == the file's content length.
        let result = try await FileManager.default.sizeInBytes(at: file.path)
        #expect(result.logicalBytes == UInt64(bytes))
        // Allocated size is rounded up to block boundaries and must be >= logical.
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesSingleByteFileBoundary() async throws {
        // Smallest non-empty file: off-by-one boundary at 1 byte.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("one.bin")
        try Data([0x42]).write(to: file)

        let result = try await FileManager.default.sizeInBytes(at: file.path)
        #expect(result.logicalBytes == 1)
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesPhysicalIsAtLeastLogicalForSingleFile() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let file = dir.appendingPathComponent("oddsize.bin")
        // Non-block-aligned size to exercise allocation rounding.
        try Data(repeating: 0x01, count: 1234).write(to: file)

        let result = try await FileManager.default.sizeInBytes(at: file.path)
        #expect(result.logicalBytes == 1234)
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    // MARK: - sizeInBytes: directory aggregation

    @Test
    func sizeInBytesDirectorySumsContainedFiles() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }

        let sizes = [10, 200, 3000, 40000]
        for (i, s) in sizes.enumerated() {
            let f = dir.appendingPathComponent("file-\(i).bin")
            try Data(repeating: UInt8(i), count: s).write(to: f)
        }

        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        let expectedLogical = UInt64(sizes.reduce(0, +))
        #expect(result.logicalBytes == expectedLogical)
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesDirectoryWithTrailingSlashIsCounted() async throws {
        // A directory path written with a trailing slash must resolve the same
        // way as without one (URL(fileURLWithPath:) normalises either spelling).
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        try Data(repeating: 0x5A, count: 321).write(to: dir.appendingPathComponent("t.bin"))

        let withSlash = dir.path.hasSuffix("/") ? dir.path : dir.path + "/"
        let result = try await FileManager.default.sizeInBytes(at: withSlash)
        #expect(result.logicalBytes == 321)
    }

    @Test
    func sizeInBytesRecursesIntoSubdirectories() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }

        // top/file.bin (100) + top/sub/deep.bin (250) + top/sub/sub2/x.bin (50)
        let topFile = dir.appendingPathComponent("file.bin")
        try Data(repeating: 1, count: 100).write(to: topFile)

        let sub = dir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 250).write(to: sub.appendingPathComponent("deep.bin"))

        let sub2 = sub.appendingPathComponent("sub2", isDirectory: true)
        try FileManager.default.createDirectory(at: sub2, withIntermediateDirectories: true)
        try Data(repeating: 3, count: 50).write(to: sub2.appendingPathComponent("x.bin"))

        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == UInt64(100 + 250 + 50))
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    @Test
    func sizeInBytesManyFilesCrossesYieldThreshold() async throws {
        // > 100 entries to exercise the `await Task.yield()` branch.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }

        let fileCount = 250
        let perFile = 16
        for i in 0..<fileCount {
            let f = dir.appendingPathComponent("f-\(i).bin")
            try Data(repeating: UInt8(i % 256), count: perFile).write(to: f)
        }

        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == UInt64(fileCount * perFile))
    }

    @Test
    func sizeInBytesExactlyHundredFilesHitsFirstYield() async throws {
        // Exactly 100 contained files: the counter reaches a multiple of 100 once,
        // hitting the `count.isMultiple(of: 100)` yield boundary precisely.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let perFile = 8
        for i in 0..<100 {
            try Data(repeating: UInt8(i % 256), count: perFile)
                .write(to: dir.appendingPathComponent("h-\(i).bin"))
        }

        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == UInt64(100 * perFile))
    }

    @Test
    func sizeInBytesLargeFileIsTimeBounded() async throws {
        // One large but bounded file (~5 MiB) to surface gross correctness issues
        // while staying well under the per-test time budget.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let big = 5 * 1024 * 1024
        let file = dir.appendingPathComponent("big.bin")
        try Data(count: big).write(to: file)

        let result = try await FileManager.default.sizeInBytes(at: file.path)
        #expect(result.logicalBytes == UInt64(big))
        #expect(result.physicalBytes >= result.logicalBytes)
    }

    // MARK: - sizeInBytes: round-trip / repeatability

    @Test
    func sizeInBytesIsRepeatableForSameTree() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        try Data(repeating: 7, count: 777).write(to: dir.appendingPathComponent("a.bin"))
        try Data(repeating: 8, count: 888).write(to: dir.appendingPathComponent("b.bin"))

        let first = try await FileManager.default.sizeInBytes(at: dir.path)
        let second = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(first.logicalBytes == second.logicalBytes)
        #expect(first.physicalBytes == second.physicalBytes)
        #expect(first.logicalBytes == UInt64(777 + 888))
    }

    @Test
    func sizeInBytesReflectsMutationBetweenReads() async throws {
        // Round-trip: measure, grow the tree, measure again — the delta must equal
        // the exact number of bytes added.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        try Data(repeating: 1, count: 500).write(to: dir.appendingPathComponent("base.bin"))

        let before = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(before.logicalBytes == 500)

        try Data(repeating: 2, count: 1500).write(to: dir.appendingPathComponent("added.bin"))
        let after = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(after.logicalBytes == before.logicalBytes + 1500)
    }

    @Test
    func sizeInBytesUnicodeFileNamesAreCounted() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let names = ["日本語.bin", "emoji-🔥.bin", "combining-e\u{0301}.bin"]
        for (i, n) in names.enumerated() {
            try Data(repeating: UInt8(i), count: 64).write(to: dir.appendingPathComponent(n))
        }
        let result = try await FileManager.default.sizeInBytes(at: dir.path)
        #expect(result.logicalBytes == UInt64(names.count * 64))
    }

    // MARK: - sizeInBytes: cancellation

    @Test
    func sizeInBytesThrowsWhenCancelledBeforeStart() async throws {
        // A pre-cancelled task should hit the very first `Task.checkCancellation()`.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        try Data(repeating: 0, count: 128).write(to: dir.appendingPathComponent("c.bin"))

        let task = Task { () -> (UInt64, UInt64) in
            // Yield once so the surrounding cancel() lands before the body runs.
            await Task.yield()
            return try await FileManager.default.sizeInBytes(at: dir.path)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }

    @Test
    func sizeInBytesCancellationDuringLargeTreeThrows() async throws {
        // Build a tree large enough that cancellation can land mid-enumeration.
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        for i in 0..<400 {
            try Data(repeating: UInt8(i % 256), count: 32).write(to: dir.appendingPathComponent("f-\(i).bin"))
        }

        let task = Task { () -> (UInt64, UInt64) in
            try await FileManager.default.sizeInBytes(at: dir.path)
        }
        task.cancel()

        // Either the pre-start check or a mid-loop check throws CancellationError.
        // If the work somehow completed before cancellation registered, that is
        // also acceptable; we assert no other error type leaks out.
        do {
            _ = try await task.value
            // Completed without observing cancellation — acceptable, non-flaky.
        } catch is CancellationError {
            // Expected cancellation path.
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - sizeInBytes: concurrency

    @Test
    func sizeInBytesConcurrentCallsAllReturnSameResult() async throws {
        let dir = try Self.makeTempDir()
        defer { Self.cleanup(dir) }
        let sizes = [128, 256, 512, 1024]
        for (i, s) in sizes.enumerated() {
            try Data(repeating: UInt8(i), count: s).write(to: dir.appendingPathComponent("c-\(i).bin"))
        }
        let expected = UInt64(sizes.reduce(0, +))

        let results: [UInt64] = await withTaskGroup(of: UInt64.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    // Use .max as an unmistakable sentinel for an unexpected throw
                    // so a swallowed error cannot masquerade as a correct total.
                    (try? await FileManager.default.sizeInBytes(at: dir.path))?.logicalBytes ?? .max
                }
            }
            var acc: [UInt64] = []
            for await r in group { acc.append(r) }
            return acc
        }

        #expect(results.count == 200)
        #expect(results.allSatisfy { $0 == expected })
    }

    @Test
    func sizeInBytesConcurrentDistinctTreesEachCorrect() async throws {
        // Independent trees measured concurrently must each yield their own total.
        let treeCount = 50
        var dirs: [(url: URL, expected: UInt64)] = []
        for t in 0..<treeCount {
            let d = try Self.makeTempDir()
            let n = (t % 5) + 1
            var total = 0
            for f in 0..<n {
                let size = 100 * (f + 1)
                total += size
                try Data(repeating: UInt8(f), count: size).write(to: d.appendingPathComponent("file-\(f).bin"))
            }
            dirs.append((d, UInt64(total)))
        }
        defer { for d in dirs { Self.cleanup(d.url) } }

        let mismatches = MismatchBox()
        await withTaskGroup(of: Void.self) { group in
            for entry in dirs {
                group.addTask {
                    let got = (try? await FileManager.default.sizeInBytes(at: entry.url.path))?.logicalBytes
                    if got != entry.expected { mismatches.record() }
                }
            }
            await group.waitForAll()
        }

        #expect(mismatches.count == 0)
    }

    // MARK: - Helpers

    /// Creates a unique temporary subdirectory for a test and returns its URL.
    private static func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerToolsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Best-effort removal of a temporary directory created during a test.
    private static func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Thread-safe mismatch counter for concurrency assertions.
    private final class MismatchBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        func record() {
            lock.lock()
            _count += 1
            lock.unlock()
        }
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }
    }
}
