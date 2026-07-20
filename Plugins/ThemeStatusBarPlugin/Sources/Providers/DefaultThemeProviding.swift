import Foundation
import LumiKernel
import LumiUI

/// 默认主题服务实现
///
/// 实现 LumiUI.LumiThemeServicing 协议。
/// 负责管理所有插件的主题贡献的注册和查询。
/// 通过 LumiUIThemeRegistry 实现主题管理功能。
@MainActor
public final class DefaultThemeProviding: LumiThemeServicing {
    public let themeRegistry: LumiUIThemeRegistry
    private var registeredThemes: [LumiUIThemeContribution] = []

    public init(themeRegistry: LumiUIThemeRegistry = .shared) {
        self.themeRegistry = themeRegistry
    }

    public var themes: [LumiUIThemeContribution] {
        themeRegistry.themes
    }

    public var selectedThemeId: String? {
        themeRegistry.selectedThemeId
    }

    public var selectedContribution: LumiUIThemeContribution? {
        themeRegistry.selectedContribution
    }

    public func selectTheme(id: String) throws {
        try themeRegistry.select(themeId: id)
    }

    /// 兼容旧版 API,实际功能由 LumiUIThemeRegistry 提供
    public func registerTheme(_ theme: LumiUIThemeContribution) {
        registeredThemes.append(theme)
        try? replaceAllThemes(registeredThemes)
    }

    public func unregisterTheme(id: String) {
        registeredThemes.removeAll { $0.id == id }
        if registeredThemes.isEmpty {
            try? themeRegistry.replaceAll([.builtInFallback()])
        } else {
            try? replaceAllThemes(registeredThemes)
        }
    }

    public func replaceAllThemes(_ themes: [LumiUIThemeContribution]) throws {
        try themeRegistry.replaceAll(themes)
    }
}
