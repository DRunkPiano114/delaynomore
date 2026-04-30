import Foundation
import ImageIO
import CoreGraphics
import AVFoundation
import UniformTypeIdentifiers

public enum CustomMediaError: Error, Equatable {
    case unreadableImage
    case downsampleFailed
    case writeFailed
}

public struct VideoInfo: Equatable {
    public let bytes: Int64
    public let durationSeconds: Double

    public init(bytes: Int64, durationSeconds: Double) {
        self.bytes = bytes
        self.durationSeconds = durationSeconds
    }
}

public enum CustomMediaStore {
    /// Maximum pixel length (longest edge) for downsampled imported images.
    public static let imageMaxEdge: Int = 4096

    /// File-size threshold above which the user is warned when importing a video.
    public static let videoSizeWarnBytes: Int64 = 200 * 1024 * 1024

    /// Duration threshold above which the user is warned when importing a video.
    public static let videoDurationWarnSeconds: Double = 5 * 60

    public static func defaultStorageDirectory(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("DelayNoMore", isDirectory: true)
            .appendingPathComponent("CustomMedia", isDirectory: true)
    }

    public static func videoInfo(at url: URL) async -> VideoInfo {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let asset = AVURLAsset(url: url)
        let durationSeconds: Double
        do {
            let cmTime = try await asset.load(.duration)
            let raw = CMTimeGetSeconds(cmTime)
            durationSeconds = (raw.isFinite && raw >= 0) ? raw : 0
        } catch {
            durationSeconds = 0
        }
        return VideoInfo(bytes: bytes, durationSeconds: durationSeconds)
    }

    public static func videoNeedsWarning(_ info: VideoInfo) -> Bool {
        info.bytes > videoSizeWarnBytes || info.durationSeconds > videoDurationWarnSeconds
    }

    @discardableResult
    public static func importImage(
        from source: URL,
        into directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil) else {
            throw CustomMediaError.unreadableImage
        }

        let preserveAlpha = isPNGSource(imageSource)
        let outputType = preserveAlpha ? UTType.png : UTType.jpeg
        let outputExt = preserveAlpha ? "png" : "jpg"

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: imageMaxEdge,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw CustomMediaError.downsampleFailed
        }

        let outputURL = directory.appendingPathComponent(
            "\(UUID().uuidString).\(outputExt)",
            isDirectory: false
        )

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            outputType.identifier as CFString,
            1,
            nil
        ) else {
            throw CustomMediaError.writeFailed
        }

        var properties: [CFString: Any] = [:]
        if !preserveAlpha {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.85
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CustomMediaError.writeFailed
        }

        return outputURL
    }

    @discardableResult
    public static func importVideo(
        from source: URL,
        into directory: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let outputURL = directory.appendingPathComponent(
            "\(UUID().uuidString).\(ext)",
            isDirectory: false
        )

        try fileManager.copyItem(at: source, to: outputURL)
        return outputURL
    }

    public static func reapOrphans(
        in directory: URL,
        keep: URL?,
        fileManager: FileManager = .default
    ) {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        let keepPath = keep?.standardizedFileURL.path
        for entry in entries {
            if entry.standardizedFileURL.path == keepPath { continue }
            try? fileManager.removeItem(at: entry)
        }
    }

    public static func isUnderStorageDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let storage = defaultStorageDirectory(fileManager: fileManager).standardizedFileURL.path
        return url.standardizedFileURL.path.hasPrefix(storage)
    }

    private static func isPNGSource(_ source: CGImageSource) -> Bool {
        guard let typeID = CGImageSourceGetType(source) else { return false }
        return UTType(typeID as String) == .png
    }
}
