import Foundation
import KitLocalization

/// Runtime localization for StoryWriterPlugin bundle.
///
/// Provides localization lookup scoped to this plugin by delegating to LumiLocalization.
enum LumiPluginLocalization {
    static let table = "Localizable"

    static func string(
        _ key: String,
        bundle: Bundle = Bundle.module,
        table: String = LumiPluginLocalization.table,
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
