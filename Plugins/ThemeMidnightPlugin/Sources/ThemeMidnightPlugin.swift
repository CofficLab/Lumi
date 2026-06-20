import LumiCoreKit
import LumiUI

public enum ThemeMidnightPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.midnight",
        displayName: LumiPluginLocalization.string("Midnight Theme", bundle: .module),
        description: LumiPluginLocalization.string("Deep dark blue color scheme", bundle: .module),
        order: 120
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight"
            )
        ]
    }
}
