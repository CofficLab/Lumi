import Foundation

public enum LumiUILocalization {
    public static func string(_ key: String, locale: Locale = .current) -> String {
        LumiUILocalizationRuntime.string(key, bundle: .module, locale: locale)
    }
    
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiUILocalizationRuntime.string(key, bundle: bundle, locale: locale)
    }
}
