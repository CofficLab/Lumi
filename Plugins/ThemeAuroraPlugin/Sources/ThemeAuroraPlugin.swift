import LumiCoreKit
import LumiUI

public enum ThemeAuroraPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.aurora",
        displayName: "Aurora Theme",
        description: "Aurora purple app theme",
        order: 121
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora"
            )
        ]
    }
}
