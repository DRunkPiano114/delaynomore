import Foundation

public enum ActiveTimerPhase: Equatable {
    case work(remainingSeconds: Int)
    case rest(remainingSeconds: Int)

    public var remainingSeconds: Int {
        switch self {
        case .work(let remainingSeconds), .rest(let remainingSeconds):
            return remainingSeconds
        }
    }

    public var isRest: Bool {
        if case .rest = self {
            return true
        }
        return false
    }
}

public enum TimerPhase: Equatable {
    case idle
    case work(remainingSeconds: Int)
    case rest(remainingSeconds: Int)
    case paused(previous: ActiveTimerPhase)

    public var isRunning: Bool {
        switch self {
        case .work, .rest:
            return true
        case .idle, .paused:
            return false
        }
    }

    public var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }

    public var isRestLike: Bool {
        switch self {
        case .rest:
            return true
        case .paused(let previous):
            return previous.isRest
        case .idle, .work:
            return false
        }
    }

    public var remainingSeconds: Int? {
        switch self {
        case .idle:
            return nil
        case .work(let remainingSeconds), .rest(let remainingSeconds):
            return remainingSeconds
        case .paused(let previous):
            return previous.remainingSeconds
        }
    }
}

public enum TimerTransition: Equatable {
    case none
    case enteredRest
    case finishedRest
}

public struct TimerModel: Equatable {
    public private(set) var phase: TimerPhase
    public private(set) var workSeconds: Int
    public private(set) var breakSeconds: Int
    public private(set) var repeats: Bool

    public init(config: AppConfig, phase: TimerPhase = .idle) {
        self.workSeconds = config.workSeconds
        self.breakSeconds = config.breakSeconds
        self.repeats = config.repeats
        self.phase = phase
    }

    public mutating func start() {
        switch phase {
        case .idle:
            phase = .work(remainingSeconds: workSeconds)
        case .paused(let previous):
            phase = previous.timerPhase
        case .work, .rest:
            break
        }
    }

    public mutating func pause() {
        switch phase {
        case .work(let remainingSeconds):
            phase = .paused(previous: .work(remainingSeconds: remainingSeconds))
        case .rest(let remainingSeconds):
            phase = .paused(previous: .rest(remainingSeconds: remainingSeconds))
        case .idle, .paused:
            break
        }
    }

    public mutating func reset(started: Bool) {
        phase = started ? .work(remainingSeconds: workSeconds) : .idle
    }

    public mutating func tick() -> TimerTransition {
        switch phase {
        case .work(let remainingSeconds) where remainingSeconds > 1:
            phase = .work(remainingSeconds: remainingSeconds - 1)
            return .none
        case .work:
            phase = .rest(remainingSeconds: breakSeconds)
            return .enteredRest
        case .rest(let remainingSeconds) where remainingSeconds > 1:
            phase = .rest(remainingSeconds: remainingSeconds - 1)
            return .none
        case .rest:
            phase = repeats ? .work(remainingSeconds: workSeconds) : .idle
            return .finishedRest
        case .idle, .paused:
            return .none
        }
    }

    public mutating func skipRest() -> TimerTransition {
        guard phase.isRestLike else {
            return .none
        }

        phase = .idle
        return .finishedRest
    }

    public mutating func setWorkSeconds(_ seconds: Int) throws {
        try AppConfig.validateWorkSeconds(seconds)
        workSeconds = seconds

        switch phase {
        case .work:
            phase = .work(remainingSeconds: workSeconds)
        case .paused(let previous):
            if case .work = previous {
                phase = .paused(previous: .work(remainingSeconds: workSeconds))
            }
        case .idle, .rest:
            break
        }
    }

    public mutating func setBreakSeconds(_ seconds: Int) throws {
        try AppConfig.validateBreakSeconds(seconds)
        breakSeconds = seconds

        switch phase {
        case .rest:
            phase = .rest(remainingSeconds: breakSeconds)
        case .paused(let previous):
            if case .rest = previous {
                phase = .paused(previous: .rest(remainingSeconds: breakSeconds))
            }
        case .idle, .work:
            break
        }
    }

    public mutating func setRepeats(_ repeats: Bool) {
        self.repeats = repeats
    }

    @available(*, deprecated, message: "Use setWorkSeconds(_:) instead.")
    public mutating func setWorkMinutes(_ minutes: Int) throws {
        try setWorkSeconds(minutes * 60)
    }

    @available(*, deprecated, message: "Use setBreakSeconds(_:) instead.")
    public mutating func setBreakMinutes(_ minutes: Int) throws {
        try setBreakSeconds(minutes * 60)
    }
}

public func formatClock(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    return String(format: "%02d:%02d", clamped / 60, clamped % 60)
}

private extension ActiveTimerPhase {
    var timerPhase: TimerPhase {
        switch self {
        case .work(let remainingSeconds):
            return .work(remainingSeconds: remainingSeconds)
        case .rest(let remainingSeconds):
            return .rest(remainingSeconds: remainingSeconds)
        }
    }
}
