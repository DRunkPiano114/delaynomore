import XCTest
@testable import DelayNoMoreCore

final class MenuPresentationTests: XCTestCase {
    func testIdleShowsStartAndHidesStop() {
        let presentation = MenuPresentation(phase: .idle, workSeconds: 1500, breakSeconds: 300)

        XCTAssertEqual(presentation.primaryAction, .start)
        XCTAssertEqual(presentation.state, .idle)
        XCTAssertFalse(presentation.stopVisible)
        XCTAssertEqual(presentation.progress, 0)
    }

    func testWorkShowsPauseAndStop() {
        let presentation = MenuPresentation(
            phase: .work(remainingSeconds: 750),
            workSeconds: 1500,
            breakSeconds: 300
        )

        XCTAssertEqual(presentation.primaryAction, .pause)
        XCTAssertEqual(presentation.state, .working(remainingSeconds: 750))
        XCTAssertTrue(presentation.stopVisible)
        XCTAssertEqual(presentation.progress, 0.5, accuracy: 0.0001)
    }

    func testRestShowsEndBreakAndHidesStop() {
        let presentation = MenuPresentation(
            phase: .rest(remainingSeconds: 60),
            workSeconds: 1500,
            breakSeconds: 300
        )

        XCTAssertEqual(presentation.primaryAction, .endBreak)
        XCTAssertEqual(presentation.state, .onBreak(remainingSeconds: 60))
        XCTAssertFalse(presentation.stopVisible)
        XCTAssertEqual(presentation.progress, 0.2, accuracy: 0.0001)
    }

    func testPausedFromWorkUsesWorkProgress() {
        let presentation = MenuPresentation(
            phase: .paused(previous: .work(remainingSeconds: 300)),
            workSeconds: 1500,
            breakSeconds: 300
        )

        XCTAssertEqual(presentation.primaryAction, .resume)
        XCTAssertEqual(presentation.state, .paused(remainingSeconds: 300))
        XCTAssertTrue(presentation.stopVisible)
        XCTAssertEqual(presentation.progress, 0.2, accuracy: 0.0001)
    }

    func testPausedFromRestUsesBreakProgress() {
        let presentation = MenuPresentation(
            phase: .paused(previous: .rest(remainingSeconds: 150)),
            workSeconds: 1500,
            breakSeconds: 300
        )

        XCTAssertEqual(presentation.primaryAction, .resume)
        XCTAssertEqual(presentation.state, .paused(remainingSeconds: 150))
        XCTAssertFalse(presentation.stopVisible)
        XCTAssertEqual(presentation.progress, 0.5, accuracy: 0.0001)
    }

    func testZeroDurationsDoNotCrash() {
        let presentation = MenuPresentation(
            phase: .work(remainingSeconds: 10),
            workSeconds: 0,
            breakSeconds: 0
        )

        XCTAssertEqual(presentation.progress, 0)
    }

    func testActionLocalizationKeys() {
        XCTAssertEqual(MenuPrimaryAction.start.localizationKey, "menu.start")
        XCTAssertEqual(MenuPrimaryAction.pause.localizationKey, "menu.pause")
        XCTAssertEqual(MenuPrimaryAction.resume.localizationKey, "menu.resume")
        XCTAssertEqual(MenuPrimaryAction.endBreak.localizationKey, "menu.endBreak")
    }

    func testActionSymbolNames() {
        XCTAssertEqual(MenuPrimaryAction.start.symbolName, "play.fill")
        XCTAssertEqual(MenuPrimaryAction.resume.symbolName, "play.fill")
        XCTAssertEqual(MenuPrimaryAction.pause.symbolName, "pause.fill")
        XCTAssertEqual(MenuPrimaryAction.endBreak.symbolName, "checkmark")
    }
}

final class FormatClockTests: XCTestCase {
    func testFormatsZeroAsDoubleZero() {
        XCTAssertEqual(formatClock(0), "00:00")
    }

    func testFormatsSecondsUnderOneMinute() {
        XCTAssertEqual(formatClock(45), "00:45")
    }

    func testFormatsMinutesAndSeconds() {
        XCTAssertEqual(formatClock(125), "02:05")
    }

    func testFormatsLargeValues() {
        XCTAssertEqual(formatClock(3725), "62:05")
    }

    func testFormatsNegativeAsZero() {
        XCTAssertEqual(formatClock(-5), "00:00")
    }
}
