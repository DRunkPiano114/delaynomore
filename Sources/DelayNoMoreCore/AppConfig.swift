import Foundation

public struct ReminderMedia: Codable, Equatable {
    public enum Kind: String, Codable {
        case customImage
        case customVideo
        case builtIn
    }

    public var kind: Kind
    public var identifier: String

    public init(kind: Kind, identifier: String) {
        self.kind = kind
        self.identifier = identifier
    }

    public static func customImage(path: String) -> ReminderMedia {
        ReminderMedia(kind: .customImage, identifier: path)
    }

    public static func customVideo(path: String) -> ReminderMedia {
        ReminderMedia(kind: .customVideo, identifier: path)
    }

    public static func builtIn(id: String) -> ReminderMedia {
        ReminderMedia(kind: .builtIn, identifier: id)
    }

    public var customPath: String? {
        switch kind {
        case .customImage, .customVideo:
            return identifier
        case .builtIn:
            return nil
        }
    }
}

public struct AppConfig: Codable, Equatable {
    public static let defaultWorkMinutes = 25
    public static let defaultBreakMinutes = 5
    public static let workMinuteRange = 1...240
    public static let breakMinuteRange = 1...60

    public static let `default` = AppConfig(
        reminder: nil,
        workMinutes: defaultWorkMinutes,
        breakMinutes: defaultBreakMinutes
    )

    public var reminder: ReminderMedia?
    public var workMinutes: Int
    public var breakMinutes: Int

    public var imagePath: String? {
        get {
            guard case .customImage = reminder?.kind else {
                return nil
            }

            return reminder?.identifier
        }
        set {
            reminder = newValue.map { .customImage(path: $0) }
        }
    }

    public init(
        reminder: ReminderMedia? = nil,
        imagePath: String? = nil,
        workMinutes: Int = defaultWorkMinutes,
        breakMinutes: Int = defaultBreakMinutes
    ) {
        self.reminder = reminder ?? imagePath.map { .customImage(path: $0) }
        self.workMinutes = workMinutes
        self.breakMinutes = breakMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case reminder
        case imagePath
        case workMinutes
        case breakMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reminder = try container.decodeIfPresent(ReminderMedia.self, forKey: .reminder)
        let legacyImagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)

        self.reminder = reminder ?? legacyImagePath.map { .customImage(path: $0) }
        self.workMinutes = try container.decodeIfPresent(Int.self, forKey: .workMinutes) ?? Self.defaultWorkMinutes
        self.breakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? Self.defaultBreakMinutes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(reminder, forKey: .reminder)
        try container.encode(workMinutes, forKey: .workMinutes)
        try container.encode(breakMinutes, forKey: .breakMinutes)
    }

    public mutating func setWorkMinutes(_ minutes: Int) throws {
        try Self.validateWorkMinutes(minutes)
        workMinutes = minutes
    }

    public mutating func setBreakMinutes(_ minutes: Int) throws {
        try Self.validateBreakMinutes(minutes)
        breakMinutes = minutes
    }

    public func validate() throws {
        try Self.validateWorkMinutes(workMinutes)
        try Self.validateBreakMinutes(breakMinutes)
    }

    public static func validateWorkMinutes(_ minutes: Int) throws {
        guard workMinuteRange.contains(minutes) else {
            throw DurationValidationError.workOutOfRange(minutes)
        }
    }

    public static func validateBreakMinutes(_ minutes: Int) throws {
        guard breakMinuteRange.contains(minutes) else {
            throw DurationValidationError.breakOutOfRange(minutes)
        }
    }
}

public enum DurationValidationError: Error, Equatable, LocalizedError {
    case workOutOfRange(Int)
    case breakOutOfRange(Int)

    public var errorDescription: String? {
        switch self {
        case .workOutOfRange:
            return "Work duration must be between 1 and 240 minutes."
        case .breakOutOfRange:
            return "Break duration must be between 1 and 60 minutes."
        }
    }
}
