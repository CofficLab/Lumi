import LumiKernel
import LumiUI

public enum ThemeDraculaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.dracula",
        displayName: LumiPluginLocalization.string("Dracula Theme", bundle: .module),
        description: LumiPluginLocalization.string("Dracula Official dark theme", bundle: .module),
        order: 132,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
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
