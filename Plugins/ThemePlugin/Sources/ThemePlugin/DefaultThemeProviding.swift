import Foundation
import LumiKernel
import LumiUI

/// 默认主题服务实现
///
/// 负责管理所有插件的主题贡献的注册和查询。
/// 通过 LumiUIThemeRegistry 实现主题管理功能。
@MainActor
public final class DefaultThemeProviding: ThemeProviding {
    public let themeRegistry: LumiUIThemeRegistry

    public init(themeRegistry: LumiUIThemeRegistry = .shared) {
        self.themeRegistry = themeRegistry
    }

    public var allThemes: [LumiUIThemeContribution] {
        themeRegistry.themes
    }

    public var selectedThemeId: String? {
        themeRegistry.selectedThemeId
    }

    public var selectedContribution: LumiUIThemeContribution? {
        themeRegistry.selectedContribution
    }

    public func registerTheme(_ theme: LumiUIThemeContribution) {
        // Note: LumiUIThemeRegistry does not support single theme registration
        // Use replaceAllThemes instead
    }

    public func unregisterTheme(id: String) {
        // Note: LumiUIThemeRegistry does not support single theme unregistration
        // Use replaceAllThemes instead
    }

    public func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws {
        try themeRegistry.replaceAll(themes)
    }

    public func selectTheme(id: String) throws {
        try themeRegistry.select(themeId: id)
    }
}