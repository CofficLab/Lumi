import Foundation
import LumiLocalizationKit

public enum KitHTMLPreviewLocalization {
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
