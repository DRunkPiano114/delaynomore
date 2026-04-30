import XCTest
@testable import DelayNoMoreAppResources

final class AppResourcesTests: XCTestCase {
    func testBundleResolvesAtAll() {
        // The custom Bundle accessor must succeed in the test runner context.
        // If this throws fatalError the test process crashes — that itself is
        // the signal something is broken.
        let bundle = AppResources.bundle
        XCTAssertNotNil(bundle.bundleURL)
    }

    func testBundleContainsLocalizableStrings() {
        let url = AppResources.bundle.url(forResource: "Localizable", withExtension: "strings")
        XCTAssertNotNil(url, "Localizable.strings missing from resource bundle")
    }

    func testBundleContainsBundledFont() {
        let url = AppResources.bundle.url(forResource: "Toriko", withExtension: "ttf")
        XCTAssertNotNil(url, "Toriko.ttf missing from resource bundle")
    }

    func testBundleContainsBuiltInVideoReminders() {
        let videos = ["fireplace", "lucky-cat", "rain-puddle", "black-cat-eyes", "cozy-cat-house", "evening-lights"]
        for name in videos {
            let url = AppResources.bundle.url(forResource: name, withExtension: "mp4")
            XCTAssertNotNil(url, "\(name).mp4 missing from resource bundle")
        }
    }

    func testLocalizedStringResolves() {
        let value = NSLocalizedString("menu.idle", bundle: AppResources.bundle, comment: "")
        XCTAssertNotEqual(value, "menu.idle", "Localizable.strings did not load — key returned as fallback")
        XCTAssertFalse(value.isEmpty)
    }
}
