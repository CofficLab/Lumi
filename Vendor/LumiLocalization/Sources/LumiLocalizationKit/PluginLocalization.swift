import Foundation

/// 插件作用域的运行时本地化服务。
///
/// 每个插件模块只需要用自身的资源 bundle 构造一次：
///
/// ```swift
/// let localized = PluginLocalization(bundle: .module)
/// ```
///
/// `Bundle.module` 在哪个模块的源文件中书写，就按词法解析为该模块的资源 bundle，
/// 因此各插件无需再维护自己的转发 shim，也无需在调用点显式传入 bundle：
///
/// ```swift
/// Text(localized.string("Settings"))
/// ```
///
/// 该类型是值类型，可安全地在模块级常量、静态上下文与实例上下文中使用。
public struct PluginLocalization: @unchecked Sendable {
    /// 资源查找使用的 bundle（通常为插件模块的 `Bundle.module`）。
    public let bundle: Bundle

    /// 字符串表名，默认 `Localizable`。
    public let table: String

    public init(bundle: Bundle, table: String = "Localizable") {
        self.bundle = bundle
        self.table = table
    }

    /// 按当前系统语言解析本地化字符串，未命中时回退为原始 key。
    public func string(_ key: String, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, table: table, locale: locale)
    }

    /// 与解析回退链一致的首选 locale。
    public func preferredLocale(_ locale: Locale = .current) -> Locale {
        LumiLocalization.preferredLocale(locale)
    }
}
