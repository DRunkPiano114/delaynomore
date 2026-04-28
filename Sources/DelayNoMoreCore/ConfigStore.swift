import Foundation

public final class ConfigStore {
    public let configURL: URL

    private let directoryURL: URL
    private let fileManager: FileManager
    private let ioQueue = DispatchQueue(label: "com.delaynomore.config-io")
    private let debounceInterval: TimeInterval
    private var pendingConfig: AppConfig?
    private var pendingWorkItem: DispatchWorkItem?

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        debounceInterval: TimeInterval = 0.25
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL(fileManager: fileManager)
        self.configURL = self.directoryURL.appendingPathComponent("config.json", isDirectory: false)
        self.debounceInterval = debounceInterval
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
        try ioQueue.sync {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            pendingConfig = nil
            try writeToDisk(config)
        }
    }

    public func scheduleSave(_ config: AppConfig) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            self.pendingWorkItem?.cancel()
            self.pendingConfig = config

            let item = DispatchWorkItem { [weak self] in
                guard let self, let pending = self.pendingConfig else { return }
                do {
                    try self.writeToDisk(pending)
                } catch {
                    NSLog("DelayNoMore: failed to persist config: \(error.localizedDescription)")
                }
                self.pendingConfig = nil
                self.pendingWorkItem = nil
            }
            self.pendingWorkItem = item
            self.ioQueue.asyncAfter(deadline: .now() + self.debounceInterval, execute: item)
        }
    }

    public func flush() {
        ioQueue.sync {
            pendingWorkItem?.cancel()
            pendingWorkItem = nil
            guard let pending = pendingConfig else { return }
            do {
                try writeToDisk(pending)
            } catch {
                NSLog("DelayNoMore: failed to persist config on flush: \(error.localizedDescription)")
            }
            pendingConfig = nil
        }
    }

    private func writeToDisk(_ config: AppConfig) throws {
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
