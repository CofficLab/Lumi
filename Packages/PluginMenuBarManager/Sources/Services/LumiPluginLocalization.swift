import Foundation
import LocalizationKit

/// Runtime localization for MenuBarManagerPlugin bundle.
///
/// Provides localization lookup scoped to this plugin by delegating to LumiLocalization.
/// `MenuBarHelperPlugin` carries its own copy with the same shape; both delegates keep
/// a single `LumiLocalization` entry point so user-facing strings stay consistent.
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
