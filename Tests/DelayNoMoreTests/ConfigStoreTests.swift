import XCTest
@testable import DelayNoMoreCore

final class ConfigStoreTests: XCTestCase {
    func testLoadReturnsDefaultWhenConfigIsMissing() {
        let store = ConfigStore(directoryURL: temporaryDirectory())

        XCTAssertEqual(store.load(), .default)
    }

    func testSaveAndLoadRoundTrip() throws {
        let store = ConfigStore(directoryURL: temporaryDirectory())
        let config = AppConfig(
            reminder: .customVideo(path: "/tmp/rest.mp4"),
            workMinutes: 45,
            breakMinutes: 10
        )

        try store.save(config)

        XCTAssertEqual(store.load(), config)
    }

    func testLoadMigratesLegacyImagePathToCustomImageReminder() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let legacyConfig = """
        {
          "imagePath": "/tmp/rest.png",
          "workMinutes": 25,
          "breakMinutes": 5
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(legacyConfig.utf8).write(to: store.configURL)

        XCTAssertEqual(store.load().reminder, .customImage(path: "/tmp/rest.png"))
    }

    func testDefaultConfigUsesCatDenReminder() {
        XCTAssertEqual(AppConfig.default.reminder, .builtIn(id: "cozy-cat-house"))
    }

    func testLoadDefaultsToBuiltInReminderWhenReminderIsMissing() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let configWithoutReminder = """
        {
          "workMinutes": 30,
          "breakMinutes": 10
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(configWithoutReminder.utf8).write(to: store.configURL)

        let loaded = store.load()
        XCTAssertEqual(loaded.reminder, AppConfig.default.reminder)
        XCTAssertEqual(loaded.workMinutes, 30)
    }

    func testInvalidDurationsAreRejected() {
        XCTAssertThrowsError(try AppConfig.validateWorkMinutes(0))
        XCTAssertThrowsError(try AppConfig.validateWorkMinutes(241))
        XCTAssertThrowsError(try AppConfig.validateBreakMinutes(0))
        XCTAssertThrowsError(try AppConfig.validateBreakMinutes(61))
    }

    func testScheduleSaveCoalescesRapidWrites() {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 0.05)

        for minutes in 26...40 {
            store.scheduleSave(AppConfig(workMinutes: minutes, breakMinutes: 5))
        }

        store.flush()

        XCTAssertEqual(store.load().workMinutes, 40)
    }

    func testFlushPersistsLatestPending() {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 60)

        store.scheduleSave(AppConfig(workMinutes: 33, breakMinutes: 7))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))

        store.flush()

        let loaded = store.load()
        XCTAssertEqual(loaded.workMinutes, 33)
        XCTAssertEqual(loaded.breakMinutes, 7)
    }

    func testSaveCancelsPendingScheduledWrite() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 60)

        store.scheduleSave(AppConfig(workMinutes: 33, breakMinutes: 7))
        try store.save(AppConfig(workMinutes: 50, breakMinutes: 10))
        store.flush()

        let loaded = store.load()
        XCTAssertEqual(loaded.workMinutes, 50)
        XCTAssertEqual(loaded.breakMinutes, 10)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
