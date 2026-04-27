import Foundation

public struct AppConfig: Codable, Equatable {
    public static let defaultWorkMinutes = 25
    public static let defaultBreakMinutes = 5
    public static let workMinuteRange = 1...240
    public static let breakMinuteRange = 1...60

    public static let `default` = AppConfig(
        imagePath: nil,
        workMinutes: defaultWorkMinutes,
        breakMinutes: defaultBreakMinutes
    )

    public var imagePath: String?
    public var workMinutes: Int
    public var breakMinutes: Int

    public init(
        imagePath: String? = nil,
        workMinutes: Int = defaultWorkMinutes,
        breakMinutes: Int = defaultBreakMinutes
    ) {
        self.imagePath = imagePath
        self.workMinutes = workMinutes
        self.breakMinutes = breakMinutes
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
