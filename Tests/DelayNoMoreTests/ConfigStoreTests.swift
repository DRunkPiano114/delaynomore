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
            workSeconds: 45 * 60 + 30,
            breakSeconds: 10 * 60 + 15,
            repeats: true
        )

        try store.save(config)

        XCTAssertEqual(store.load(), config)
    }

    func testSaveWritesSecondBasedDurations() throws {
        let store = ConfigStore(directoryURL: temporaryDirectory())

        try store.save(AppConfig(workSeconds: 90, breakSeconds: 15))

        let data = try Data(contentsOf: store.configURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["workSeconds"] as? Int, 90)
        XCTAssertEqual(object["breakSeconds"] as? Int, 15)
        XCTAssertEqual(object["repeats"] as? Bool, false)
        XCTAssertNil(object["workMinutes"])
        XCTAssertNil(object["breakMinutes"])
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

    func testLoadMigratesLegacyMinutesToSeconds() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let legacyConfig = """
        {
          "workMinutes": 30,
          "breakMinutes": 10
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(legacyConfig.utf8).write(to: store.configURL)

        let loaded = store.load()
        XCTAssertEqual(loaded.workSeconds, 1800)
        XCTAssertEqual(loaded.breakSeconds, 600)
        XCTAssertFalse(loaded.repeats)
    }

    func testLoadReadsRepeatSetting() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let config = """
        {
          "workSeconds": 90,
          "breakSeconds": 15,
          "repeats": true
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(config.utf8).write(to: store.configURL)

        XCTAssertTrue(store.load().repeats)
    }

    func testDefaultConfigUsesCatDenReminder() {
        XCTAssertEqual(AppConfig.default.reminder, .builtIn(id: "cozy-cat-house"))
        XCTAssertFalse(AppConfig.default.repeats)
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
        XCTAssertEqual(loaded.workSeconds, 1800)
    }

    func testLoadDefaultsDurationsWhenTheyAreMissing() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let configWithoutDurations = """
        {
          "reminder": {
            "kind": "builtIn",
            "identifier": "cozy-cat-house"
          }
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(configWithoutDurations.utf8).write(to: store.configURL)

        let loaded = store.load()
        XCTAssertEqual(loaded.workSeconds, AppConfig.defaultWorkSeconds)
        XCTAssertEqual(loaded.breakSeconds, AppConfig.defaultBreakSeconds)
    }

    func testInvalidDurationsAreRejected() {
        XCTAssertThrowsError(try AppConfig.validateWorkSeconds(0))
        XCTAssertThrowsError(try AppConfig.validateWorkSeconds(14_401))
        XCTAssertThrowsError(try AppConfig.validateBreakSeconds(0))
        XCTAssertThrowsError(try AppConfig.validateBreakSeconds(3_601))
    }

    func testLoadFallsBackToDefaultWhenDurationsAreInvalid() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory)
        let invalidConfig = """
        {
          "workSeconds": 0,
          "breakSeconds": 300
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(invalidConfig.utf8).write(to: store.configURL)

        XCTAssertEqual(store.load(), .default)
    }

    func testScheduleSaveCoalescesRapidWrites() {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 0.05)

        for seconds in 26...40 {
            store.scheduleSave(AppConfig(workSeconds: seconds, breakSeconds: 5))
        }

        store.flush()

        XCTAssertEqual(store.load().workSeconds, 40)
    }

    func testFlushPersistsLatestPending() {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 60)

        store.scheduleSave(AppConfig(workSeconds: 33, breakSeconds: 7))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.configURL.path))

        store.flush()

        let loaded = store.load()
        XCTAssertEqual(loaded.workSeconds, 33)
        XCTAssertEqual(loaded.breakSeconds, 7)
    }

    func testSaveCancelsPendingScheduledWrite() throws {
        let directory = temporaryDirectory()
        let store = ConfigStore(directoryURL: directory, debounceInterval: 60)

        store.scheduleSave(AppConfig(workSeconds: 33, breakSeconds: 7))
        try store.save(AppConfig(workSeconds: 50, breakSeconds: 10))
        store.flush()

        let loaded = store.load()
        XCTAssertEqual(loaded.workSeconds, 50)
        XCTAssertEqual(loaded.breakSeconds, 10)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
