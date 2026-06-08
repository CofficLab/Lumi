import LumiCoreKit
import LumiUI

public enum ThemeAutumnPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.autumn",
        displayName: "Autumn Theme",
        description: "Autumn orange app theme",
        order: 126
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn"
            )
        ]
    }
}
