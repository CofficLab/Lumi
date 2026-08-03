import Foundation
import LumiKernel

enum PluginDiskManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable", locale: locale)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
