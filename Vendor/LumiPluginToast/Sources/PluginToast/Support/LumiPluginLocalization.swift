import Foundation
import LumiLocalizationKit

/// PluginToast 的运行时本地化。
///
/// 委托 `LumiLocalization` 按插件 bundle 的 Localizable 表查找，
/// 源语言为英语（en），并随系统语言偏好回退到 `.xcstrings` catalog。
enum LumiPluginLocalization {
    static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
