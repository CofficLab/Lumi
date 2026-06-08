import LumiCoreKit
import LumiUI

public enum ThemeNebulaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.nebula",
        displayName: "星云粉 Theme",
        description: "浪漫的星云粉，柔和而温暖",
        order: 122
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula"
            )
        ]
    }
}
