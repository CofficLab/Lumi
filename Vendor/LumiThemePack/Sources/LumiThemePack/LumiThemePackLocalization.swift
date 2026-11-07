import Foundation

public enum LumiThemePackLocalization {
    public static func string(_ key: String, locale: Locale = .current) -> String {
        string(key, bundle: .module, locale: locale)
    }

    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle, locale: locale)
    }
}
