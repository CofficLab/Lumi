import Foundation
import LumiKernel

/// CAD Designer 本地化 helper（复用 LumiPluginLocalization）。
enum CADDesignerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }

    static func string(_ key: String, for language: LumiLanguagePreference) -> String {
        _ = language
        return string(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
