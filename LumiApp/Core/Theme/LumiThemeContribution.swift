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
    let fileIconThemeContributor: AnyObject?

    /// 创建主题贡献。
    ///
    /// 列表顺序由所属插件的 `SuperPlugin.order` 决定（见 `AppPluginVM.getThemeContributions()`）。
    ///
    /// - Parameters:
    ///   - appTheme: App 全局主题（实现 `SuperTheme`）
    ///   - editorThemeId: 编辑器主题唯一标识
    ///   - editorThemeContributor: 编辑器主题贡献者（遵循 `SuperEditorThemeContributor`，类型擦除为 `AnyObject` 避免内核依赖编辑器库）
    ///   - fileIconThemeContributor: 文件树图标主题贡献者（遵循 `LumiFileIconThemeContributor`，类型擦除为 `AnyObject` 保持插件侧简单）
    init(
        appTheme: any SuperTheme,
        editorThemeId: String,
        editorThemeContributor: AnyObject? = nil,
        fileIconThemeContributor: AnyObject? = nil
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
        self.fileIconThemeContributor = fileIconThemeContributor
    }
}

/// 内置主题清单（用于兜底和内置主题插件复用）。
enum LumiBuiltinThemeCatalog {
    static let defaultThemeId = "lumi"

    @MainActor
    static func themes() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(appTheme: LumiTheme(), editorThemeId: "lumi-dark"),
        ]
    }
}
