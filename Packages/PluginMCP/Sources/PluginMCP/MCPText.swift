import Foundation
import KitLocalization

/// PluginMCP bundle 的运行时本地化封装。
///
/// 委托 `LumiLocalization`；未命中时返回原始 key，保证 UI 不空白。
/// 后续如需多语言，补充 `Localizable.xcstrings` 即可。
enum MCPText {
    static func string(
        _ key: String,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: .module, table: table, locale: locale)
    }
}
