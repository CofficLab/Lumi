import LumiCoreKit
import LumiUI

public enum ThemeOneDarkPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.one-dark",
        displayName: String(localized: "One Dark Theme", bundle: .module),
        description: String(localized: "Atom One Dark classic dark theme", bundle: .module),
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
