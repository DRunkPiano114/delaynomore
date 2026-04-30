import Foundation

public enum AppResources {
    public static let bundle: Bundle = {
        let bundleName = "DelayNoMore_DelayNoMoreAppResources.bundle"

        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: BundleFinder.self).bundleURL.deletingLastPathComponent()
        ]

        for candidate in candidates {
            if let url = candidate?.appendingPathComponent(bundleName),
               let bundle = Bundle(url: url) {
                return bundle
            }
        }

        fatalError("Could not find resource bundle '\(bundleName)'")
    }()
}

private final class BundleFinder {}
