import Foundation
import LocalizationKit

/// Runtime localization for ThemeMountainPlugin bundle.
///
/// Provides localization lookup scoped to this plugin by delegating to LumiLocalization.
enum LumiPluginLocalization {
    static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
