import Foundation
import LocalizationKit

/// IdleTime 插件的运行时本地化。
///
/// 与 PluginDevice 等复刻插件保持一致：委托 `LumiLocalization` 按
/// 插件 bundle 的 Localizable 表查找。
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
