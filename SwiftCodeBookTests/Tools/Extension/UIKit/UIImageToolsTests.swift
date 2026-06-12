//
//  UIImageToolsTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: Source/Tools/Extension/UIKit/UIImage+Tools.swift
//
//  Covers the public UIImage extension surface:
//    - static color(_:size:): solid-color image generation, default-size
//      behavior, validSelfOrOne sanitization of bad sizes (zero / negative /
//      NaN / infinity), pixel-color correctness, fractional-size boundary,
//      and scale handling.
//    - fixOrientation(): identity for .up orientation, new image for rotated
//      orientations, size/content/scale preservation.
//    - init?(filePath:): success from a real temp file (PNG + JPEG), nil for
//      missing/empty/directory paths and for non-image data, unicode paths,
//      and round-trips.
//    - init?(symbolName:pointSize:): valid SF Symbols, invalid point sizes
//      (0, negative, NaN, infinity), and unknown / empty / whitespace names.
//
//  All UIKit drawing happens on the main actor, so the whole suite is
//  @MainActor.
//

#if canImport(UIKit)
import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import SwiftCodeBook

@MainActor
@Suite struct UIImageToolsTests {

    // MARK: - Helpers

    /// Reads the RGBA pixel at (x, y) of `image`'s underlying CGImage.
    /// Returns nil when there is no CGImage backing or the read fails.
    private static func pixel(_ image: UIImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let cg = image.cgImage else { return nil }
        let width = cg.width
        let height = cg.height
        guard width > 0, height > 0, x >= 0, y >= 0, x < width, y < height else { return nil }

        var data = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        let offset = (y * width + x) * 4
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }

    /// A temp directory unique per call; caller is responsible for cleanup.
    private static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIImageToolsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - color(_:size:) happy path

    @Test func colorProducesNonEmptyImageWithRequestedSize() {
        let size = CGSize(width: 10, height: 20)
        let image = UIImage.color(.red, size: size)
        // The renderer produces a logical (point) size equal to the request.
        #expect(image.size.width == 10)
        #expect(image.size.height == 20)
        // And it must be backed by a real CGImage.
        #expect(image.cgImage != nil)
    }

    @Test func colorDefaultSizeIsOneByOne() {
        let image = UIImage.color(.blue)
        #expect(image.size == .one)
        #expect(image.size == CGSize(width: 1, height: 1))
    }

    @Test func colorExplicitOneSizeMatchesDefault() {
        let defaulted = UIImage.color(.blue)
        let explicit = UIImage.color(.blue, size: .one)
        #expect(defaulted.size == explicit.size)
        #expect(explicit.size == CGSize(width: 1, height: 1))
    }

    @Test func colorPixelMatchesOpaqueRed() throws {
        let image = UIImage.color(.red, size: CGSize(width: 4, height: 4))
        let px = try #require(Self.pixel(image, x: 0, y: 0))
        // Opaque red: R=255, G=0, B=0, A=255 (premultiplied has no effect at full alpha).
        #expect(px.r == 255)
        #expect(px.g == 0)
        #expect(px.b == 0)
        #expect(px.a == 255)
    }

    @Test func colorPixelMatchesOpaqueGreenCenter() throws {
        let image = UIImage.color(.green, size: CGSize(width: 8, height: 8))
        let px = try #require(Self.pixel(image, x: 4, y: 4))
        // UIColor.green is (0,1,0).
        #expect(px.r == 0)
        #expect(px.g == 255)
        #expect(px.b == 0)
        #expect(px.a == 255)
    }

    @Test func colorFullyTransparentClearColor() throws {
        let image = UIImage.color(.clear, size: CGSize(width: 3, height: 3))
        let px = try #require(Self.pixel(image, x: 1, y: 1))
        // Clear fill -> alpha 0 (premultiplied -> all components 0).
        #expect(px.a == 0)
        #expect(px.r == 0)
        #expect(px.g == 0)
        #expect(px.b == 0)
    }

    @Test func colorFillsEveryCorner() throws {
        // The fill spans the whole rect, so all four corners must be the fill color.
        let image = UIImage.color(.red, size: CGSize(width: 5, height: 5))
        let cg = try #require(image.cgImage)
        let maxX = cg.width - 1
        let maxY = cg.height - 1
        for (x, y) in [(0, 0), (maxX, 0), (0, maxY), (maxX, maxY)] {
            let px = try #require(Self.pixel(image, x: x, y: y))
            #expect(px.r == 255)
            #expect(px.g == 0)
            #expect(px.b == 0)
            #expect(px.a == 255)
        }
    }

    // MARK: - color size sanitization (validSelfOrOne)

    // Sizes that are NOT valid must fall back to 1x1. CGSize.isValid requires
    // both dimensions finite and strictly > 0.
    @Test(arguments: [
        CGSize(width: 0, height: 0),
        CGSize(width: 0, height: 5),
        CGSize(width: 5, height: 0),
        CGSize(width: -3, height: -3),
        CGSize(width: -1, height: 10),
        CGSize(width: 10, height: -1),
    ])
    func colorInvalidSizeFallsBackToOne(badSize: CGSize) {
        let image = UIImage.color(.purple, size: badSize)
        #expect(image.size == .one)
    }

    @Test func colorNaNSizeFallsBackToOne() {
        let nan = CGFloat.nan
        let image = UIImage.color(.purple, size: CGSize(width: nan, height: nan))
        #expect(image.size == .one)
    }

    @Test(arguments: [
        CGSize(width: CGFloat.infinity, height: 10),
        CGSize(width: 10, height: CGFloat.infinity),
        CGSize(width: -CGFloat.infinity, height: 10),
        CGSize(width: CGFloat.nan, height: 10),
        CGSize(width: 10, height: CGFloat.nan),
    ])
    func colorNonFiniteSizeFallsBackToOne(badSize: CGSize) {
        let image = UIImage.color(.purple, size: badSize)
        #expect(image.size == .one)
    }

    @Test func colorValidNonSquareSizePreserved() {
        let image = UIImage.color(.orange, size: CGSize(width: 7, height: 3))
        #expect(image.size == CGSize(width: 7, height: 3))
    }

    @Test func colorTinyFractionalSizeIsValidAndPreserved() throws {
        // Boundary just above 0: any finite value > 0 is valid, so the logical
        // size is preserved rather than falling back to 1x1.
        let tiny = CGSize(width: 0.4, height: 0.6)
        let image = UIImage.color(.red, size: tiny)
        #expect(abs(image.size.width - 0.4) < 1e-9)
        #expect(abs(image.size.height - 0.6) < 1e-9)
        // It still produces a (rounded-up to at least 1px) backing image.
        let cg = try #require(image.cgImage)
        #expect(cg.width >= 1)
        #expect(cg.height >= 1)
    }

    @Test func colorLargeSizeProducesProportionalPixels() throws {
        // Large but time-bounded: 500x400 = 200k pixels.
        let image = UIImage.color(.red, size: CGSize(width: 500, height: 400))
        #expect(image.size == CGSize(width: 500, height: 400))
        let cg = try #require(image.cgImage)
        let scale = image.scale
        #expect(cg.width == Int((500 * scale).rounded()))
        #expect(cg.height == Int((400 * scale).rounded()))
    }

    @Test func colorScaleIsPositive() {
        let image = UIImage.color(.black, size: CGSize(width: 2, height: 2))
        #expect(image.scale > 0)
    }

    @Test func colorDifferentColorsProduceDifferentPixels() throws {
        let red = try #require(Self.pixel(UIImage.color(.red, size: .one), x: 0, y: 0))
        let blue = try #require(Self.pixel(UIImage.color(.blue, size: .one), x: 0, y: 0))
        #expect(red != blue)
    }

    // MARK: - fixOrientation()

    @Test func fixOrientationUpReturnsSameInstance() {
        // .up is the default orientation for renderer-produced images.
        let original = UIImage.color(.red, size: CGSize(width: 5, height: 5))
        #expect(original.imageOrientation == .up)
        let fixed = original.fixOrientation()
        // Guard clause returns `self` unchanged when already .up.
        #expect(fixed === original)
    }

    @Test func fixOrientationNonUpReturnsNewImage() throws {
        let base = UIImage.color(.red, size: CGSize(width: 6, height: 4))
        let cg = try #require(base.cgImage)
        // Reinterpret as a rotated orientation; this is not .up so it gets redrawn.
        let rotated = UIImage(cgImage: cg, scale: base.scale, orientation: .left)
        #expect(rotated.imageOrientation == .left)

        let fixed = rotated.fixOrientation()
        // A brand-new, normalized image is produced.
        #expect(fixed !== rotated)
        #expect(fixed.imageOrientation == .up)
        #expect(fixed.cgImage != nil)
    }

    @Test func fixOrientationLeftSwapsLogicalDimensions() throws {
        // For a 90-degree (.left / .right) orientation, UIImage.size reports the
        // swapped dimensions; normalizing must keep the same displayed size.
        let base = UIImage.color(.green, size: CGSize(width: 8, height: 4))
        let cg = try #require(base.cgImage)
        let rotated = UIImage(cgImage: cg, scale: base.scale, orientation: .left)
        let fixed = rotated.fixOrientation()
        // fixOrientation draws into a context the size of `rotated.size`.
        #expect(fixed.size == rotated.size)
    }

    @Test func fixOrientationDownReturnsNewUpImage() throws {
        let base = UIImage.color(.blue, size: CGSize(width: 5, height: 5))
        let cg = try #require(base.cgImage)
        let down = UIImage(cgImage: cg, scale: base.scale, orientation: .down)
        let fixed = down.fixOrientation()
        #expect(fixed !== down)
        #expect(fixed.imageOrientation == .up)
        #expect(fixed.size == down.size)
    }

    @Test func fixOrientationPreservesSolidColorContent() throws {
        // A solid-color image is invariant under any orientation transform, so
        // normalizing a reoriented copy must keep the same fill color.
        let base = UIImage.color(.blue, size: CGSize(width: 6, height: 6))
        let cg = try #require(base.cgImage)
        let down = UIImage(cgImage: cg, scale: base.scale, orientation: .down)
        let fixed = down.fixOrientation()
        let fixedCG = try #require(fixed.cgImage)
        let px = try #require(Self.pixel(fixed, x: fixedCG.width / 2, y: fixedCG.height / 2))
        // UIColor.blue is (0,0,1).
        #expect(px.r == 0)
        #expect(px.g == 0)
        #expect(px.b == 255)
        #expect(px.a == 255)
    }

    @Test(arguments: [
        UIImage.Orientation.upMirrored,
        .down,
        .downMirrored,
        .left,
        .leftMirrored,
        .right,
        .rightMirrored,
    ])
    func fixOrientationAllNonUpNormalizeToUp(orientation: UIImage.Orientation) throws {
        let base = UIImage.color(.magenta, size: CGSize(width: 4, height: 6))
        let cg = try #require(base.cgImage)
        let reoriented = UIImage(cgImage: cg, scale: base.scale, orientation: orientation)
        let fixed = reoriented.fixOrientation()
        #expect(fixed.imageOrientation == .up)
        #expect(fixed.cgImage != nil)
        // The displayed (logical) size is preserved regardless of orientation.
        #expect(fixed.size == reoriented.size)
    }

    @Test func fixOrientationPreservesScale() throws {
        let base = UIImage.color(.red, size: CGSize(width: 4, height: 4))
        let cg = try #require(base.cgImage)
        let rotated = UIImage(cgImage: cg, scale: 3.0, orientation: .right)
        let fixed = rotated.fixOrientation()
        // The renderer format is seeded from `imageRendererFormat`, so scale is kept.
        #expect(abs(fixed.scale - 3.0) < 1e-9)
    }

    // MARK: - init?(filePath:)

    @Test func initFilePathSucceedsForValidImageFile() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = UIImage.color(.red, size: CGSize(width: 8, height: 8))
        let data = try #require(source.pngData())
        let fileURL = dir.appendingPathComponent("image.png")
        try data.write(to: fileURL)

        let loaded = try #require(UIImage(filePath: fileURL.path))
        // PNG round-trip keeps the pixel dimensions.
        let loadedCG = try #require(loaded.cgImage)
        #expect(loadedCG.width == 8)
        #expect(loadedCG.height == 8)
    }

    @Test func initFilePathRoundTripPreservesColor() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = UIImage.color(.green, size: CGSize(width: 4, height: 4))
        let data = try #require(source.pngData())
        let fileURL = dir.appendingPathComponent("green.png")
        try data.write(to: fileURL)

        let loaded = try #require(UIImage(filePath: fileURL.path))
        let px = try #require(Self.pixel(loaded, x: 0, y: 0))
        #expect(px.g == 255)
        #expect(px.r == 0)
        #expect(px.b == 0)
        #expect(px.a == 255)
    }

    @Test func initFilePathSucceedsForJPEGFile() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = UIImage.color(.blue, size: CGSize(width: 16, height: 12))
        let data = try #require(source.jpegData(compressionQuality: 1.0))
        let fileURL = dir.appendingPathComponent("image.jpg")
        try data.write(to: fileURL)

        let loaded = try #require(UIImage(filePath: fileURL.path))
        let loadedCG = try #require(loaded.cgImage)
        #expect(loadedCG.width == 16)
        #expect(loadedCG.height == 12)
    }

    @Test func initFilePathSucceedsForUnicodePath() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = UIImage.color(.orange, size: CGSize(width: 5, height: 5))
        let data = try #require(source.pngData())
        // Unicode + emoji in the file name to exercise path handling.
        let fileURL = dir.appendingPathComponent("图片-テスト-🌈.png")
        try data.write(to: fileURL)

        let loaded = try #require(UIImage(filePath: fileURL.path))
        let loadedCG = try #require(loaded.cgImage)
        #expect(loadedCG.width == 5)
        #expect(loadedCG.height == 5)
    }

    @Test func initFilePathReturnsNilForMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("definitely-not-here-\(UUID().uuidString).png")
        #expect(UIImage(filePath: missing.path) == nil)
    }

    @Test func initFilePathReturnsNilForEmptyPath() {
        #expect(UIImage(filePath: "") == nil)
    }

    @Test func initFilePathReturnsNilForNonImageData() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Data exists but is not a decodable image.
        let fileURL = dir.appendingPathComponent("garbage.bin")
        let garbage = Data("this is not an image, just plain text".utf8)
        try garbage.write(to: fileURL)

        // Data load succeeds, but UIImage(data:) fails -> nil.
        #expect(UIImage(filePath: fileURL.path) == nil)
    }

    @Test func initFilePathReturnsNilForEmptyFile() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("empty.png")
        try Data().write(to: fileURL)

        // Empty data -> UIImage(data:) returns nil.
        #expect(UIImage(filePath: fileURL.path) == nil)
    }

    @Test func initFilePathReturnsNilForDirectoryPath() {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // A directory cannot be read as Data -> nil.
        #expect(UIImage(filePath: dir.path) == nil)
    }

    // MARK: - init?(symbolName:pointSize:)

    @Test(arguments: ["star", "star.fill", "heart", "trash", "gear"])
    func initSymbolSucceedsForKnownSymbols(name: String) throws {
        let image = try #require(
            UIImage(symbolName: name, pointSize: 24),
            "Expected SF Symbol \(name) to load"
        )
        #expect(image.isSymbolImage)
    }

    @Test(arguments: [1.0, 8.0, 17.0, 64.0, 200.0] as [CGFloat])
    func initSymbolSucceedsForVariousPositiveSizes(pointSize: CGFloat) {
        #expect(UIImage(symbolName: "circle", pointSize: pointSize) != nil)
    }

    @Test func initSymbolReturnsNilForZeroPointSize() {
        #expect(UIImage(symbolName: "star", pointSize: 0) == nil)
    }

    @Test(arguments: [-1.0, -0.001, -100.0] as [CGFloat])
    func initSymbolReturnsNilForNegativePointSize(pointSize: CGFloat) {
        #expect(UIImage(symbolName: "star", pointSize: pointSize) == nil)
    }

    @Test func initSymbolReturnsNilForNaNPointSize() {
        #expect(UIImage(symbolName: "star", pointSize: .nan) == nil)
    }

    @Test func initSymbolReturnsNilForInfinitePointSize() {
        #expect(UIImage(symbolName: "star", pointSize: .infinity) == nil)
        #expect(UIImage(symbolName: "star", pointSize: -.infinity) == nil)
    }

    @Test func initSymbolReturnsNilForUnknownSymbolName() {
        // Point size is valid, but the symbol does not exist -> systemName fails.
        #expect(UIImage(symbolName: "this.symbol.does.not.exist.\(UUID().uuidString)", pointSize: 20) == nil)
    }

    @Test func initSymbolReturnsNilForEmptySymbolName() {
        #expect(UIImage(symbolName: "", pointSize: 20) == nil)
    }

    @Test func initSymbolReturnsNilForWhitespaceSymbolName() {
        // Whitespace is not a valid symbol name -> systemName lookup fails.
        #expect(UIImage(symbolName: "   ", pointSize: 20) == nil)
        #expect(UIImage(symbolName: "\n\t", pointSize: 20) == nil)
    }

    @Test func initSymbolGuardRunsBeforeSystemNameLookup() {
        // Even a valid-looking symbol must be rejected when pointSize is invalid:
        // the finiteness/positivity guard short-circuits first.
        #expect(UIImage(symbolName: "star.fill", pointSize: 0) == nil)
        #expect(UIImage(symbolName: "star.fill", pointSize: .nan) == nil)
    }

    @Test func initSymbolTinyPositivePointSizeSucceeds() {
        // Boundary just above 0: a very small but finite, positive size passes the
        // guard and yields a symbol image.
        #expect(UIImage(symbolName: "circle", pointSize: 0.001) != nil)
    }

    // MARK: - Concurrency

    @Test func colorIsSafeUnderConcurrentMainActorTasks() async {
        // color is @MainActor; hammer it via many awaited tasks and assert all
        // results are well-formed. Each child task hops to the main actor.
        let results = await withTaskGroup(of: CGSize.self, returning: [CGSize].self) { group in
            for i in 0..<200 {
                group.addTask { @MainActor in
                    let side = CGFloat((i % 16) + 1)
                    return UIImage.color(.red, size: CGSize(width: side, height: side)).size
                }
            }
            var collected: [CGSize] = []
            for await size in group {
                collected.append(size)
            }
            return collected
        }
        #expect(results.count == 200)
        // Every generated size must be a valid, non-degenerate square.
        #expect(results.allSatisfy { $0.width >= 1 && $0.height >= 1 && $0.width == $0.height })
    }

    @Test func symbolInitIsSafeUnderConcurrentTasks() async {
        let nilCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for i in 0..<300 {
                group.addTask { @MainActor in
                    // Alternate between valid and invalid point sizes.
                    let pointSize: CGFloat = (i % 2 == 0) ? CGFloat(i % 30 + 1) : -1
                    return UIImage(symbolName: "circle", pointSize: pointSize) == nil
                }
            }
            var nils = 0
            for await wasNil in group where wasNil {
                nils += 1
            }
            return nils
        }
        // Exactly the 150 odd-indexed (negative point size) calls must be nil.
        #expect(nilCount == 150)
    }

    @Test func fixOrientationIsSafeUnderConcurrentTasks() async {
        // Normalize many reoriented images concurrently; all results must be .up.
        let upCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            let orientations: [UIImage.Orientation] = [.up, .down, .left, .right, .upMirrored]
            for i in 0..<150 {
                let orientation = orientations[i % orientations.count]
                group.addTask { @MainActor in
                    let base = UIImage.color(.red, size: CGSize(width: 4, height: 4))
                    guard let cg = base.cgImage else { return false }
                    let reoriented = UIImage(cgImage: cg, scale: base.scale, orientation: orientation)
                    return reoriented.fixOrientation().imageOrientation == .up
                }
            }
            var ups = 0
            for await wasUp in group where wasUp {
                ups += 1
            }
            return ups
        }
        // Every normalization yields an .up image.
        #expect(upCount == 150)
    }
}
#endif
