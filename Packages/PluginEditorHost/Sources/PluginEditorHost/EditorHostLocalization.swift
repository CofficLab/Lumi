import Foundation
import KitLocalization

enum EditorHostLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: .module, locale: locale)
    }
}
