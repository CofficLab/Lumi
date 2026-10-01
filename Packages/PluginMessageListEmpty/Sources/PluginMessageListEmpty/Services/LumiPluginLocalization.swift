import Foundation
import LumiLocalizationKit

enum LumiPluginLocalization {
    static func string(
        _ key: String,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: .module, table: table, locale: locale)
    }
}
