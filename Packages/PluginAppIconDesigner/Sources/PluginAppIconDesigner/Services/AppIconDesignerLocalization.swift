import Foundation

enum AppIconDesignerLocalization {
    static func string(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
