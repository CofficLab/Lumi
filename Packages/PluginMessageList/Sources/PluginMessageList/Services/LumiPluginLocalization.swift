import Foundation
import KitLocalization

/// Runtime localization for PluginMessageList bundle.
///
/// 新版包暂未内嵌 `Localizable.xcstrings` 资源，因此回退到宿主 Bundle.main
/// 查找本地化文案（旧版是插件自带的 bundle: .module）。若后续为插件补充
/// 独立资源目录，把 `bundle` 参数换回 `.module` 即可。
enum LumiPluginLocalization {
    static func string(
        _ key: String,
        table: String = "Localizable",
        locale: Locale = .current
    ) -> String {
        LumiLocalization.string(key, bundle: .main, table: table, locale: locale)
    }
}
