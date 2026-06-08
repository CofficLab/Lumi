import LumiCoreKit
import LumiUI

public enum ThemeDraculaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.dracula",
        displayName: "Dracula Theme",
        description: "Dracula Official dark theme",
        order: 132
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: DraculaTheme(),
                editorThemeId: "dracula"
            )
        ]
    }
}
