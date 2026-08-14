import Foundation
import KernelLumi

/// 原型设计插件的本地化：按 key 从本插件 `Resources/Localizable.xcstrings` 取文案。
///
/// 与 `AppIconDesignerLocalization` 一致，便于在工具与视图中共用。
enum PrototypeDesignerLocalization {
    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }
}
