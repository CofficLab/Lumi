import LumiKernel
import LumiUI
import os

public enum ThemeWinterPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.winter")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.winter",
        displayName: LumiPluginLocalization.string("Winter Theme", bundle: .module),
        description: LumiPluginLocalization.string("Winter cool app theme", bundle: .module),
        order: 127,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter"
            )
        ]
    }
}
