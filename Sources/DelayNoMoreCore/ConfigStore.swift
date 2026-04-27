import Foundation

public final class ConfigStore {
    public let configURL: URL

    private let directoryURL: URL
    private let fileManager: FileManager

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.configURL = self.directoryURL.appendingPathComponent("config.json", isDirectory: false)
    }

    public func load() -> AppConfig {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            try config.validate()
            return config
        } catch {
            return .default
        }
    }

    public func save(_ config: AppConfig) throws {
        try config.validate()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        return baseURL.appendingPathComponent("DelayNoMore", isDirectory: true)
    }
}
