import Foundation
import KitLocalization

/// ProviderRootView 的运行时本地化。
///
/// 委托 `LumiLocalization` 按插件 bundle 的 Localizable 表查找。
public enum LumiPluginLocalization {
    /// ProviderRootView 包的 Bundle，用于外部访问本地化资源。
    public static let bundle = Bundle.module
    
    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
