import LumiCoreKit
import LumiUI

public enum ThemeVoidPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.void",
        displayName: "虚空深黑 Theme",
        description: "纯粹的虚空黑，深邃而神秘",
        order: 123
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void"
            )
        ]
    }
}
