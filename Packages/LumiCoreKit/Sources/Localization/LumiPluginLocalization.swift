import Foundation
import LumiLocalizationKit

/// Runtime localization for Swift Package Manager plugin bundles.
///
/// `String(localized:bundle: .module)` does not read compiled `.lproj` resources in plugin bundles.
/// Use this helper to resolve strings from `.lproj` files with `.xcstrings` fallback.
///
/// - Note: This is a forwarding wrapper around `LumiLocalizationKit`. New code should prefer
///     `LumiLocalization.string(...)` directly. This type is preserved for backward compatibility
///     with existing plugin call sites.
public enum LumiPluginLocalization {
    public static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }

    /// Locale aligned with plugin string resolution (`Locale.preferredLanguages` first).
    public static func preferredLocale(_ locale: Locale = .current) -> Locale {
        LumiLocalization.preferredLocale(locale)
    }
}
