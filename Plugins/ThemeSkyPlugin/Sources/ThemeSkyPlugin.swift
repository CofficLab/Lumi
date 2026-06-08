import LumiCoreKit
import LumiUI

public enum ThemeSkyPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.sky",
        displayName: "Sky Theme",
        description: "Sky inspired app theme that adapts to system appearance",
        order: 120
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SkyTheme(),
                editorThemeId: "sky-dark"
            )
        ]
    }
}
