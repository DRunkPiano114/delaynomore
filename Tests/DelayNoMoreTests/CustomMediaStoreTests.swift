import XCTest
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
@testable import DelayNoMoreCore
@testable import DelayNoMoreAppResources

final class CustomMediaStoreTests: XCTestCase {
    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CustomMediaStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    func testDefaultStorageDirectoryEndsWithExpectedPath() {
        let url = CustomMediaStore.defaultStorageDirectory()
        XCTAssertTrue(url.path.hasSuffix("/Application Support/DelayNoMore/CustomMedia"))
    }

    func testImportImageDownsamplesLongestEdge() throws {
        let source = try writeTestImage(
            width: 4000,
            height: 3000,
            type: .jpeg,
            into: workDir.appendingPathComponent("source.jpg")
        )

        let output = try CustomMediaStore.importImage(from: source, into: workDir.appendingPathComponent("Imported"))

        let dimensions = try imageDimensions(of: output)
        XCTAssertLessThanOrEqual(max(dimensions.width, dimensions.height), CustomMediaStore.imageMaxEdge)
        XCTAssertEqual(output.pathExtension, "jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
    }

    func testImportImagePreservesPNGFormatForAlpha() throws {
        let source = try writeTestImage(
            width: 800,
            height: 600,
            type: .png,
            into: workDir.appendingPathComponent("source.png")
        )

        let output = try CustomMediaStore.importImage(from: source, into: workDir.appendingPathComponent("Imported"))

        XCTAssertEqual(output.pathExtension, "png")
    }

    func testImportImageReturnsURLUnderProvidedDirectory() throws {
        let source = try writeTestImage(
            width: 600,
            height: 400,
            type: .jpeg,
            into: workDir.appendingPathComponent("source.jpg")
        )
        let importDir = workDir.appendingPathComponent("Imported", isDirectory: true)

        let output = try CustomMediaStore.importImage(from: source, into: importDir)

        XCTAssertEqual(output.deletingLastPathComponent().standardizedFileURL, importDir.standardizedFileURL)
    }

    func testImportImageThrowsOnUnreadableSource() {
        let source = workDir.appendingPathComponent("does-not-exist.png")
        XCTAssertThrowsError(try CustomMediaStore.importImage(from: source, into: workDir))
    }

    func testImportVideoCopiesFile() throws {
        guard let bundled = AppResources.bundle.url(forResource: "lucky-cat", withExtension: "mp4") else {
            XCTFail("Bundled lucky-cat.mp4 not found — required for this test")
            return
        }

        let importDir = workDir.appendingPathComponent("Imported")
        let output = try CustomMediaStore.importVideo(from: bundled, into: importDir)

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let sourceSize = try bundled.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
        let outputSize = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -2
        XCTAssertEqual(sourceSize, outputSize)
        XCTAssertEqual(output.pathExtension, "mp4")
    }

    func testReapOrphansDeletesEverythingExceptKeep() throws {
        let dir = workDir.appendingPathComponent("Reap")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let kept = dir.appendingPathComponent("keep.txt")
        let trash1 = dir.appendingPathComponent("a.txt")
        let trash2 = dir.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: kept)
        try Data("b".utf8).write(to: trash1)
        try Data("c".utf8).write(to: trash2)

        CustomMediaStore.reapOrphans(in: dir, keep: kept)

        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: trash1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: trash2.path))
    }

    func testReapOrphansDeletesAllWhenKeepIsNil() throws {
        let dir = workDir.appendingPathComponent("Reap")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let trash1 = dir.appendingPathComponent("a.txt")
        let trash2 = dir.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: trash1)
        try Data("b".utf8).write(to: trash2)

        CustomMediaStore.reapOrphans(in: dir, keep: nil)

        XCTAssertFalse(FileManager.default.fileExists(atPath: trash1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: trash2.path))
    }

    func testReapOrphansSilentOnMissingDirectory() {
        let dir = workDir.appendingPathComponent("does-not-exist")
        // Should not throw / crash.
        CustomMediaStore.reapOrphans(in: dir, keep: nil)
    }

    func testVideoNeedsWarningRespectsBothThresholds() {
        let small = VideoInfo(bytes: 10_000_000, durationSeconds: 30)
        XCTAssertFalse(CustomMediaStore.videoNeedsWarning(small))

        let bigBytes = VideoInfo(bytes: CustomMediaStore.videoSizeWarnBytes + 1, durationSeconds: 30)
        XCTAssertTrue(CustomMediaStore.videoNeedsWarning(bigBytes))

        let longDuration = VideoInfo(bytes: 1_000_000, durationSeconds: CustomMediaStore.videoDurationWarnSeconds + 1)
        XCTAssertTrue(CustomMediaStore.videoNeedsWarning(longDuration))
    }

    func testVideoInfoReadsSizeAndDuration() async throws {
        guard let bundled = AppResources.bundle.url(forResource: "lucky-cat", withExtension: "mp4") else {
            XCTFail("Bundled lucky-cat.mp4 not found — required for this test")
            return
        }

        let info = await CustomMediaStore.videoInfo(at: bundled)
        XCTAssertGreaterThan(info.bytes, 0)
        XCTAssertGreaterThan(info.durationSeconds, 0)
    }

    // MARK: - Helpers

    private func writeTestImage(width: Int, height: Int, type: UTType, into url: URL) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo
        switch type {
        case .png:
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        default:
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "TestSetup", code: 1)
        }

        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "TestSetup", code: 2)
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            type.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "TestSetup", code: 3)
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "TestSetup", code: 4)
        }

        return url
    }

    private func imageDimensions(of url: URL) throws -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw NSError(domain: "TestSetup", code: 5)
        }
        return (width, height)
    }
}
