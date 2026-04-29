import AppKit
import AVFoundation
import DelayNoMoreCore
import UniformTypeIdentifiers

enum ReminderMediaAsset {
    case image(NSImage)
    case video(URL)
    case pixelScene
}

struct BuiltInReminderMedia {
    enum MediaKind {
        case image
        case video
        case pixelScene
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
            id: "pixel-diorama",
            title: L10n.string("settings.media.pixel"),
            resourceName: "",
            resourceExtension: "",
            kind: .pixelScene
        ),
        BuiltInReminderMedia(
            id: "lucky-cat",
            title: "Lucky Cat",
            resourceName: "lucky-cat",
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

    private static var previewCache: [String: NSImage] = [:]

    static func previewImage(for media: ReminderMedia?) -> NSImage? {
        guard let media else { return nil }

        let key = "\(media.kind.rawValue):\(media.identifier)"
        if let cached = previewCache[key] { return cached }

        guard let asset = asset(for: media) else { return nil }

        let image: NSImage?
        switch asset {
        case .image(let img): image = img
        case .video(let url): image = videoThumbnail(url: url)
        case .pixelScene: image = PixelSceneAssets.previewThumbnail()
        }

        if let image { previewCache[key] = image }
        return image
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
        guard let builtIn = builtIns.first(where: { $0.id == id }) else {
            return nil
        }

        switch builtIn.kind {
        case .pixelScene:
            return PixelSceneAssets.areAvailable ? .pixelScene : nil
        case .image:
            guard let url = Bundle.module.url(
                forResource: builtIn.resourceName,
                withExtension: builtIn.resourceExtension
            ),
            let image = NSImage(contentsOf: url) else {
                return nil
            }

            return .image(image)
        case .video:
            guard let url = Bundle.module.url(
                forResource: builtIn.resourceName,
                withExtension: builtIn.resourceExtension
            ) else {
                return nil
            }

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
