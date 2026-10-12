import Foundation
import LumiLocalizationKit

enum CodeEditorLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: .module, locale: locale)
    }
}
