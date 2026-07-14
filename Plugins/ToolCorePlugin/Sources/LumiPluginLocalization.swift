import Foundation
import LumiLocalizationKit

/// Runtime localization for ToolCorePlugin bundle.
///
/// Provides localization lookup scoped to ToolCorePlugin by delegating
/// to `LumiLocalizationKit`. This wrapper exists for backward compatibility
/// with existing call sites.
enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
