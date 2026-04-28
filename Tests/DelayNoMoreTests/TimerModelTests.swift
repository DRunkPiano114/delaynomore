import XCTest
@testable import DelayNoMoreCore

final class TimerModelTests: XCTestCase {
    func testInitializesDurationsFromSecondsConfig() {
        let config = AppConfig(workSeconds: 90, breakSeconds: 15)
        let model = TimerModel(config: config)

        XCTAssertEqual(model.workSeconds, 90)
        XCTAssertEqual(model.breakSeconds, 15)
        XCTAssertFalse(model.repeats)
    }

    func testWorkTransitionsToRest() throws {
        let config = AppConfig(workSeconds: 90, breakSeconds: 15)
        var model = TimerModel(config: config, phase: .work(remainingSeconds: 1))

        XCTAssertEqual(model.tick(), .enteredRest)
        XCTAssertEqual(model.phase, .rest(remainingSeconds: 15))
    }

    func testRestTransitionsToIdle() throws {
        let config = AppConfig(workSeconds: 90, breakSeconds: 1)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 1))

        XCTAssertEqual(model.tick(), .finishedRest)
        XCTAssertEqual(model.phase, .idle)
    }

    func testRestTransitionsToWorkWhenRepeating() throws {
        let config = AppConfig(workSeconds: 90, breakSeconds: 1, repeats: true)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 1))

        XCTAssertEqual(model.tick(), .finishedRest)
        XCTAssertEqual(model.phase, .work(remainingSeconds: 90))
    }

    func testChangingRepeatSettingAffectsNextBreakEnd() {
        let config = AppConfig(workSeconds: 90, breakSeconds: 1)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 1))

        model.setRepeats(true)

        XCTAssertEqual(model.tick(), .finishedRest)
        XCTAssertEqual(model.phase, .work(remainingSeconds: 90))
    }

    func testSkippingRestReturnsToIdle() {
        let config = AppConfig(workSeconds: 1500, breakSeconds: 300)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 300))

        XCTAssertEqual(model.skipRest(), .finishedRest)
        XCTAssertEqual(model.phase, .idle)
    }

    func testChangingCurrentWorkDurationResetsWorkRemainingTime() throws {
        let config = AppConfig(workSeconds: 1500, breakSeconds: 300)
        var model = TimerModel(config: config, phase: .work(remainingSeconds: 100))

        try model.setWorkSeconds(90)

        XCTAssertEqual(model.phase, .work(remainingSeconds: 90))
    }

    func testChangingCurrentBreakDurationResetsBreakRemainingTime() throws {
        let config = AppConfig(workSeconds: 1500, breakSeconds: 300)
        var model = TimerModel(config: config, phase: .rest(remainingSeconds: 100))

        try model.setBreakSeconds(45)

        XCTAssertEqual(model.phase, .rest(remainingSeconds: 45))
    }
}
