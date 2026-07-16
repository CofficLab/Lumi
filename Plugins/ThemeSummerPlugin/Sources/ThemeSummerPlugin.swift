import LumiCoreKit
import LumiUI
import os

public enum ThemeSummerPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.summer")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.summer",
        displayName: LumiPluginLocalization.string("Summer Theme", bundle: .module),
        description: LumiPluginLocalization.string("Summer blue app theme", bundle: .module),
        order: 125,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer"
            )
        ]
    }
}
