import Foundation
import LocalizationKit

enum PromoLocalization {
    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: .module, table: "Localizable", locale: .current)
    }
}
