import Foundation
import LumiLocalizationKit

enum PluginAppManagerLocalization {
    static func string(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
