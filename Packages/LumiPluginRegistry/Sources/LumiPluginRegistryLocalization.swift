import Foundation
import LumiCoreKit
import LocalizationKit

public enum LumiPluginRegistryLocalization {
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
