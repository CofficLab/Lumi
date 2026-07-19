import Foundation
import LumiUI

/// 主题能力协议
///
/// 定义 LumiCore 需要的主题管理功能，由具体插件实现。
/// 继承 `LumiThemeServicing` 以保持与现有代码的兼容性。
@MainActor
public protocol ThemeProviding: AnyObject, LumiThemeServicing {
    /// 所有已注册的主题贡献
    var allThemes: [LumiUIThemeContribution] { get }

    /// 注册主题贡献
    func registerTheme(_ theme: LumiUIThemeContribution)

    /// 注销主题
    func unregisterTheme(id: String)

    /// 替换所有主题
    func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws
}

/// Default implementation for LumiThemeServicing compatibility
public extension ThemeProviding {
    /// Alias for allThemes to satisfy LumiThemeServicing
    public var themes: [LumiUIThemeContribution] {
        allThemes
    }
}