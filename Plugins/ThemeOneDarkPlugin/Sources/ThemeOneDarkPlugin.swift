import LumiCoreKit
import LumiUI

public enum ThemeOneDarkPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.one-dark",
        displayName: "One Dark Theme",
        description: "Atom One Dark classic dark theme",
        order: 131
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OneDarkTheme(),
                editorThemeId: "one-dark"
            )
        ]
    }
}
