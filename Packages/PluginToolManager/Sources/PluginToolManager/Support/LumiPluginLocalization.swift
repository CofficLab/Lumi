import Foundation
import KitLocalization

/// ToolManager 插件的运行时本地化。
///
/// 委托 `LumiLocalization` 按插件 bundle 的 Localizable 表查找。
enum LumiPluginLocalization {
    static func string(
        _ key: String,
        bundle: Bundle,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }
}
