import Foundation
import LocalizationKit

enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
