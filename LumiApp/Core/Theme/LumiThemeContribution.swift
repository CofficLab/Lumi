import SwiftUI

/// Lumi 统一主题贡献模型：
/// 一个主题同时定义 App 主题外观与编辑器主题 ID。
struct LumiThemeContribution: Identifiable {
    let id: String
    let displayName: String
    let compactName: String
    let description: String
    let iconName: String
    let iconColor: SwiftUI.Color
    let appTheme: any ThemeProtocol
    let editorThemeId: String
    let order: Int

    init(appTheme: any ThemeProtocol, editorThemeId: String, order: Int = 0) {
        self.id = appTheme.identifier
        self.displayName = appTheme.displayName
        self.compactName = appTheme.compactName
        self.description = appTheme.description
        self.iconName = appTheme.iconName
        self.iconColor = appTheme.iconColor
        self.appTheme = appTheme
        self.editorThemeId = editorThemeId
        self.order = order
    }
}

/// 内置主题清单（用于兜底和内置主题插件复用）。
enum LumiBuiltinThemeCatalog {
    static let defaultThemeId = "midnight"
    static let selectedThemeKey = "LumiTheme.SelectedThemeID"
    static let legacySelectedThemeKey = "MystiqueTheme.SelectedVariant"

    @MainActor
    static func themes() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(appTheme: MidnightTheme(), editorThemeId: "midnight", order: 10),
        ]
    }
}
