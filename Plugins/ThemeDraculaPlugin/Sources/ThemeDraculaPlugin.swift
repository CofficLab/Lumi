import LumiCoreKit
import LumiUI

public enum ThemeDraculaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.dracula",
        displayName: LumiPluginLocalization.string("Dracula Theme", bundle: .module),
        description: LumiPluginLocalization.string("Dracula Official dark theme", bundle: .module),
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
