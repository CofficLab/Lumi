import Foundation
import LocalizationKit

enum AgentTurnRunnerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: LumiLocalization.preferredLocale(), arguments: arguments)
    }
}
