import Foundation

enum PluginAppManagerLocalization {
    static let table = "AppManager"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: table, bundle: bundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
