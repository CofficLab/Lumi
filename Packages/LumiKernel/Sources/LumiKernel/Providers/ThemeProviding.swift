import Foundation
import LumiUI

/// 主题能力协议
///
/// 定义 LumiCore 需要的主题管理功能，由具体插件实现。
@MainActor
public protocol ThemeProviding: AnyObject {
    /// 所有已注册的主题贡献
    var allThemes: [LumiUIThemeContribution] { get }

    /// 注册主题贡献
    func registerTheme(_ theme: LumiUIThemeContribution)

    /// 注销主题
    func unregisterTheme(id: String)

    /// 替换所有主题
    func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws
}

/// 默认主题服务实现
@MainActor
public final class DefaultThemeProviding: ThemeProviding {

    private var themes: [String: LumiUIThemeContribution] = [:]
    private var themeOrder: [String] = []

    public init() {}

    public var allThemes: [LumiUIThemeContribution] {
        themeOrder.compactMap { themes[$0] }
    }

    public func registerTheme(_ theme: LumiUIThemeContribution) {
        if themes[theme.id] == nil {
            themeOrder.append(theme.id)
        }
        themes[theme.id] = theme
    }

    public func unregisterTheme(id: String) {
        themes.removeValue(forKey: id)
        themeOrder.removeAll { $0 == id }
    }

    public func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws {
        self.themes.removeAll()
        self.themeOrder.removeAll()
        for theme in themes {
            registerTheme(theme)
        }
    }
}