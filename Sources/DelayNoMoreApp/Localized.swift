import Foundation
import DelayNoMoreAppResources

enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: AppResources.bundle, comment: "")
    }

    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: AppResources.bundle, comment: "")
        return String(format: format, locale: .current, arguments: arguments)
    }
}
