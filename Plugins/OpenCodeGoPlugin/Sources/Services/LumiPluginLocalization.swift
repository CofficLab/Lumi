import Foundation
import LocalizationKit

/// Self-contained localization helper for OpenCodeGoPlugin.
/// Does not depend on LumiLocalizationKit — falls back to the key itself when no bundle is found.
public enum LumiPluginLocalization {
    public static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
