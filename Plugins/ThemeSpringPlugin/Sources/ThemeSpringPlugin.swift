import LumiCoreKit
import LumiUI

public enum ThemeSpringPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.spring",
        displayName: String(localized: "Spring Theme", bundle: .module),
        description: String(localized: "Spring green app theme", bundle: .module),
        order: 124
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SpringTheme(),
                editorThemeId: "spring"
            )
        ]
    }
}
