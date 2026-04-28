import Foundation

public enum MenuPrimaryAction: Equatable {
    case start
    case pause
    case resume
    case endBreak

    public var localizationKey: String {
        switch self {
        case .start: return "menu.start"
        case .pause: return "menu.pause"
        case .resume: return "menu.resume"
        case .endBreak: return "menu.endBreak"
        }
    }

    public var symbolName: String {
        switch self {
        case .start, .resume: return "play.fill"
        case .pause: return "pause.fill"
        case .endBreak: return "checkmark"
        }
    }
}

public enum MenuStateKind: Equatable {
    case idle
    case working(remainingSeconds: Int)
    case onBreak(remainingSeconds: Int)
    case paused(remainingSeconds: Int)
}

public struct MenuPresentation: Equatable {
    public let primaryAction: MenuPrimaryAction
    public let state: MenuStateKind
    public let stopVisible: Bool
    public let progress: Double

    public init(phase: TimerPhase, workSeconds: Int, breakSeconds: Int) {
        switch phase {
        case .idle:
            primaryAction = .start
            state = .idle
            stopVisible = false
            progress = 0

        case .work(let remaining):
            primaryAction = .pause
            state = .working(remainingSeconds: remaining)
            stopVisible = true
            progress = Self.fraction(remaining, of: workSeconds)

        case .rest(let remaining):
            primaryAction = .endBreak
            state = .onBreak(remainingSeconds: remaining)
            stopVisible = false
            progress = Self.fraction(remaining, of: breakSeconds)

        case .paused(let previous):
            primaryAction = .resume
            switch previous {
            case .work(let remaining):
                state = .paused(remainingSeconds: remaining)
                stopVisible = true
                progress = Self.fraction(remaining, of: workSeconds)
            case .rest(let remaining):
                state = .paused(remainingSeconds: remaining)
                stopVisible = false
                progress = Self.fraction(remaining, of: breakSeconds)
            }
        }
    }

    private static func fraction(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }
}
