import Foundation
import LumiCoreKit

enum LumiUILocalization {
    static func string(
        _ key: String,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiPluginLocalization.string(key, bundle: .module, table: table, locale: locale)
    }
}
