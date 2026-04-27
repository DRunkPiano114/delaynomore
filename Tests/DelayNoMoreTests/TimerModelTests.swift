import XCTest
@testable import DelayNoMoreCore

final class TimerModelTests: XCTestCase {
    func testWorkTransitionsToRest() throws {
        let config = AppConfig(workMinutes: 1, breakMinutes: 1)
        var model = TimerModel(config: config, phase: .work(remainingSeconds: 1))

        XCTAssertEqual(model.tick(), .enteredRest)
        XCTAssertEqual(model.phase, .rest(remainingSeconds: 60))
    }

    func testRestTransitionsToIdle() throws {
        let config = AppConfig(workMinutes: 1, breakMinutes: 1)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 1))

        XCTAssertEqual(model.tick(), .finishedRest)
        XCTAssertEqual(model.phase, .idle)
    }

    func testSkippingRestReturnsToIdle() {
        let config = AppConfig(workMinutes: 25, breakMinutes: 5)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 300))

        XCTAssertEqual(model.skipRest(), .finishedRest)
        XCTAssertEqual(model.phase, .idle)
    }

    func testChangingCurrentWorkDurationResetsWorkRemainingTime() throws {
        let config = AppConfig(workMinutes: 25, breakMinutes: 5)
        var model = TimerModel(config: config, phase: .work(remainingSeconds: 100))

        try model.setWorkMinutes(10)

        XCTAssertEqual(model.phase, .work(remainingSeconds: 600))
    }

    func testChangingCurrentBreakDurationResetsBreakRemainingTime() throws {
        let config = AppConfig(workMinutes: 25, breakMinutes: 5)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 100))

        try model.setBreakMinutes(2)

        XCTAssertEqual(model.phase, .rest(remainingSeconds: 120))
    }
}
