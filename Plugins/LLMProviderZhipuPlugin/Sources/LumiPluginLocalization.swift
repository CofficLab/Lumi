import Foundation
import LumiLocalizationKit

/// Runtime localization for Zhipu plugin bundle.
///
/// Provides localization lookup scoped to Zhipu plugin by delegating to
/// `LumiLocalizationKit`. This wrapper exists for backward compatibility with
/// existing Zhipu call sites that previously used `LumiPluginLocalization`.
enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
