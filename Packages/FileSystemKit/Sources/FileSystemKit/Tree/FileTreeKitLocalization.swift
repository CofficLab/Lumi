import Foundation
import LocalizationKit

public enum FileTreeKitLocalization {
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
