import Foundation
import LumiLocalizationKit

/// Runtime localization for ThemeWinterPlugin bundle.
///
/// Provides localization lookup scoped to ThemeWinterPlugin by delegating to LumiLocalization.
enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
