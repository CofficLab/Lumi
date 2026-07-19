import LumiKernel
import LumiUI

public enum ThemeLumiPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.lumi",
        displayName: LumiPluginLocalization.string("Lumi Theme", bundle: .module),
        description: LumiPluginLocalization.string("Provides the default Lumi theme.", bundle: .module),
        order: 100,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
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
