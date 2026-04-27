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
            imagePath: "/tmp/rest.png",
            workMinutes: 45,
            breakMinutes: 10
        )

        try store.save(config)

        XCTAssertEqual(store.load(), config)
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
