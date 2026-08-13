import Foundation

enum OnboardingPageLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiPluginLocalization.string(
            key,
            bundle: .module,
            table: "OnboardingPages",
            locale: locale
        )
    }
}
