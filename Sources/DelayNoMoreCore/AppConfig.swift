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
    public static let defaultWorkSeconds = 50 * 60
    public static let defaultBreakSeconds = 10 * 60
    public static let maximumDurationSeconds = (59 * 60 * 60) + (59 * 60) + 59
    public static let workSecondRange = 1...maximumDurationSeconds
    public static let breakSecondRange = 1...maximumDurationSeconds

    @available(*, deprecated, message: "Use defaultWorkSeconds instead.")
    public static let defaultWorkMinutes = defaultWorkSeconds / 60
    @available(*, deprecated, message: "Use defaultBreakSeconds instead.")
    public static let defaultBreakMinutes = defaultBreakSeconds / 60
    @available(*, deprecated, message: "Use workSecondRange instead.")
    public static let workMinuteRange = 1...(maximumDurationSeconds / 60)
    @available(*, deprecated, message: "Use breakSecondRange instead.")
    public static let breakMinuteRange = 1...(maximumDurationSeconds / 60)

    public static let `default` = AppConfig(
        reminder: .builtIn(id: "pixel-diorama"),
        workSeconds: defaultWorkSeconds,
        breakSeconds: defaultBreakSeconds,
        repeats: false
    )

    public var reminder: ReminderMedia?
    public var workSeconds: Int
    public var breakSeconds: Int
    public var repeats: Bool

    @available(*, deprecated, message: "Use workSeconds instead.")
    public var workMinutes: Int {
        get { workSeconds / 60 }
        set { workSeconds = newValue * 60 }
    }

    @available(*, deprecated, message: "Use breakSeconds instead.")
    public var breakMinutes: Int {
        get { breakSeconds / 60 }
        set { breakSeconds = newValue * 60 }
    }

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
        workSeconds: Int = defaultWorkSeconds,
        breakSeconds: Int = defaultBreakSeconds,
        repeats: Bool = false
    ) {
        self.reminder = reminder ?? imagePath.map { .customImage(path: $0) }
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
        self.repeats = repeats
    }

    @available(*, deprecated, message: "Use init(reminder:imagePath:workSeconds:breakSeconds:) instead.")
    public init(
        reminder: ReminderMedia? = nil,
        imagePath: String? = nil,
        workMinutes: Int,
        breakMinutes: Int,
        repeats: Bool = false
    ) {
        self.init(
            reminder: reminder,
            imagePath: imagePath,
            workSeconds: workMinutes * 60,
            breakSeconds: breakMinutes * 60,
            repeats: repeats
        )
    }

    private enum CodingKeys: String, CodingKey {
        case reminder
        case imagePath
        case workSeconds
        case breakSeconds
        case repeats
        case workMinutes
        case breakMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reminder = try container.decodeIfPresent(ReminderMedia.self, forKey: .reminder)
        let legacyImagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
        let workSeconds = try container.decodeIfPresent(Int.self, forKey: .workSeconds)
        let breakSeconds = try container.decodeIfPresent(Int.self, forKey: .breakSeconds)
        let legacyWorkMinutes = try container.decodeIfPresent(Int.self, forKey: .workMinutes)
        let legacyBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .breakMinutes)

        self.reminder = reminder ?? legacyImagePath.map { .customImage(path: $0) } ?? Self.default.reminder
        self.workSeconds = workSeconds ?? legacyWorkMinutes.map { $0 * 60 } ?? Self.defaultWorkSeconds
        self.breakSeconds = breakSeconds ?? legacyBreakMinutes.map { $0 * 60 } ?? Self.defaultBreakSeconds
        self.repeats = try container.decodeIfPresent(Bool.self, forKey: .repeats) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(reminder, forKey: .reminder)
        try container.encode(workSeconds, forKey: .workSeconds)
        try container.encode(breakSeconds, forKey: .breakSeconds)
        try container.encode(repeats, forKey: .repeats)
    }

    public mutating func setWorkSeconds(_ seconds: Int) throws {
        try Self.validateWorkSeconds(seconds)
        workSeconds = seconds
    }

    public mutating func setBreakSeconds(_ seconds: Int) throws {
        try Self.validateBreakSeconds(seconds)
        breakSeconds = seconds
    }

    @available(*, deprecated, message: "Use setWorkSeconds(_:) instead.")
    public mutating func setWorkMinutes(_ minutes: Int) throws {
        try setWorkSeconds(minutes * 60)
    }

    @available(*, deprecated, message: "Use setBreakSeconds(_:) instead.")
    public mutating func setBreakMinutes(_ minutes: Int) throws {
        try setBreakSeconds(minutes * 60)
    }

    public func validate() throws {
        try Self.validateWorkSeconds(workSeconds)
        try Self.validateBreakSeconds(breakSeconds)
    }

    public static func validateWorkSeconds(_ seconds: Int) throws {
        guard workSecondRange.contains(seconds) else {
            throw DurationValidationError.workOutOfRange(seconds)
        }
    }

    public static func validateBreakSeconds(_ seconds: Int) throws {
        guard breakSecondRange.contains(seconds) else {
            throw DurationValidationError.breakOutOfRange(seconds)
        }
    }

    @available(*, deprecated, message: "Use validateWorkSeconds(_:) instead.")
    public static func validateWorkMinutes(_ minutes: Int) throws {
        try validateWorkSeconds(minutes * 60)
    }

    @available(*, deprecated, message: "Use validateBreakSeconds(_:) instead.")
    public static func validateBreakMinutes(_ minutes: Int) throws {
        try validateBreakSeconds(minutes * 60)
    }
}

public enum DurationValidationError: Error, Equatable, LocalizedError {
    case workOutOfRange(Int)
    case breakOutOfRange(Int)

    public var errorDescription: String? {
        switch self {
        case .workOutOfRange:
            return "Work duration must be between 1 second and 59:59:59."
        case .breakOutOfRange:
            return "Break duration must be between 1 second and 59:59:59."
        }
    }
}
