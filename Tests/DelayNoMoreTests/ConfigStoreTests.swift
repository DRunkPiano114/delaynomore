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

    func testInvalidDurationsAreRejected() {
        XCTAssertThrowsError(try AppConfig.validateWorkMinutes(0))
        XCTAssertThrowsError(try AppConfig.validateWorkMinutes(241))
        XCTAssertThrowsError(try AppConfig.validateBreakMinutes(0))
        XCTAssertThrowsError(try AppConfig.validateBreakMinutes(61))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
