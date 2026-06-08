import LumiCoreKit
import LumiUI

public enum ThemeLumiPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.lumi",
        displayName: "Lumi Theme",
        description: "Provides the default Lumi theme.",
        order: 100
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: LumiTheme(),
                editorThemeId: "lumi-dark"
            )
        ]
    }
}
