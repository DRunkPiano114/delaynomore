import AppKit
import AVFoundation
import DelayNoMoreCore
import UniformTypeIdentifiers

enum ReminderMediaAsset {
    case image(NSImage)
    case video(URL)
}

struct BuiltInReminderMedia {
    enum MediaKind {
        case image
        case video
    }

    let id: String
    let title: String
    let resourceName: String
    let resourceExtension: String
    let kind: MediaKind
}

enum ReminderMediaLibrary {
    static let allowedContentTypes: [UTType] = [.image, .movie, .video]

    static let builtIns: [BuiltInReminderMedia] = [
        BuiltInReminderMedia(
            id: "lucky-cat",
            title: "Lucky Cat",
            resourceName: "lucky-cat",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "cartoon-fox-skunk",
            title: "Fox & Skunk",
            resourceName: "cartoon-fox-skunk",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "cozy-cat-house",
            title: "Cat Den",
            resourceName: "cozy-cat-house",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "black-cat-eyes",
            title: "Black Cat",
            resourceName: "black-cat-eyes",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "fireplace",
            title: "Fireplace",
            resourceName: "fireplace",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "rain-puddle",
            title: "Rain on Puddle",
            resourceName: "rain-puddle",
            resourceExtension: "mp4",
            kind: .video
        ),
        BuiltInReminderMedia(
            id: "evening-lights",
            title: "Evening Lights",
            resourceName: "evening-lights",
            resourceExtension: "mp4",
            kind: .video
        )
    ]

    static func asset(for media: ReminderMedia) -> ReminderMediaAsset? {
        switch media.kind {
        case .customImage:
            guard let image = NSImage(contentsOfFile: media.identifier) else {
                return nil
            }

            return .image(image)
        case .customVideo:
            let url = URL(fileURLWithPath: media.identifier)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            return .video(url)
        case .builtIn:
            return builtInAsset(id: media.identifier)
        }
    }

    static func media(for url: URL) -> ReminderMedia? {
        if isImage(url), NSImage(contentsOf: url) != nil {
            return .customImage(path: url.path)
        }

        if isMovie(url), FileManager.default.fileExists(atPath: url.path) {
            return .customVideo(path: url.path)
        }

        return nil
    }

    static func title(for media: ReminderMedia?) -> String {
        guard let media else {
            return "None"
        }

        switch media.kind {
        case .customImage, .customVideo:
            return URL(fileURLWithPath: media.identifier).lastPathComponent
        case .builtIn:
            return builtIns.first { $0.id == media.identifier }?.title ?? media.identifier
        }
    }

    static func previewImage(for media: ReminderMedia?) -> NSImage? {
        guard let media, let asset = asset(for: media) else {
            return nil
        }

        switch asset {
        case .image(let image):
            return image
        case .video(let url):
            return videoThumbnail(url: url)
        }
    }

    static func videoURL(for media: ReminderMedia?) -> URL? {
        guard let media, let asset = asset(for: media) else { return nil }
        if case .video(let url) = asset { return url }
        return nil
    }

    static func isAvailable(_ media: ReminderMedia?) -> Bool {
        guard let media else {
            return false
        }

        return asset(for: media) != nil
    }

    private static func builtInAsset(id: String) -> ReminderMediaAsset? {
        guard let builtIn = builtIns.first(where: { $0.id == id }),
              let url = Bundle.module.url(
                  forResource: builtIn.resourceName,
                  withExtension: builtIn.resourceExtension
              ) else {
            return nil
        }

        switch builtIn.kind {
        case .image:
            guard let image = NSImage(contentsOf: url) else {
                return nil
            }

            return .image(image)
        case .video:
            return .video(url)
        }
    }

    private static func isImage(_ url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .image) == true
    }

    private static func isMovie(_ url: URL) -> Bool {
        guard let contentType = contentType(for: url) else {
            return false
        }

        return contentType.conforms(to: .movie) || contentType.conforms(to: .video)
    }

    private static func contentType(for url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }

        return UTType(filenameExtension: url.pathExtension)
    }

    private static func videoThumbnail(url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
