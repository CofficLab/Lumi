import AgentToolKit
import Foundation
import LumiCoreKit

enum AppIconDesignerLocalization {
    static let table = "AppIconDesigner"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
