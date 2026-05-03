import SwiftUI

/// Lumi 统一主题贡献模型：
/// 一个主题同时定义 App 主题外观与编辑器主题。
///
/// 插件通过 `SuperPlugin.addThemeContributions()` 返回此模型，
/// 即可一次性注入 App 全局主题 + 编辑器语法高亮主题。
struct LumiThemeContribution: Identifiable {
    let id: String
    let displayName: String
    let compactName: String
    let description: String
    let iconName: String
    let iconColor: SwiftUI.Color
    let appTheme: any SuperTheme
    let editorThemeId: String
    let editorThemeContributor: AnyObject?
    let order: Int

    /// 创建主题贡献。
    ///
    /// - Parameters:
    ///   - appTheme: App 全局主题（实现 `SuperTheme`）
    ///   - editorThemeId: 编辑器主题唯一标识
    ///   - editorThemeContributor: 编辑器主题贡献者（遵循 `SuperEditorThemeContributor`，类型擦除为 `AnyObject` 避免内核依赖编辑器库）
    ///   - order: 排序权重
    init(
        appTheme: any SuperTheme,
        editorThemeId: String,
        editorThemeContributor: AnyObject? = nil,
        order: Int = 0
    ) {
        self.id = appTheme.identifier
        self.displayName = appTheme.displayName
        self.compactName = appTheme.compactName
        self.description = appTheme.description
        self.iconName = appTheme.iconName
        self.iconColor = appTheme.iconColor
        self.appTheme = appTheme
        self.editorThemeId = editorThemeId
        self.editorThemeContributor = editorThemeContributor
        self.order = order
    }
}

/// 内置主题清单（用于兜底和内置主题插件复用）。
enum LumiBuiltinThemeCatalog {
    static let defaultThemeId = "midnight"

    @MainActor
    static func themes() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(appTheme: MidnightTheme(), editorThemeId: "midnight", order: 10),
        ]
    }
}
