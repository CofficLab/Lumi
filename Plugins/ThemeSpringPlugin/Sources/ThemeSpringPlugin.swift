import LumiCoreKit
import LumiUI
import os

public enum ThemeSpringPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.spring")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.spring",
        displayName: LumiPluginLocalization.string("Spring Theme", bundle: .module),
        description: LumiPluginLocalization.string("Spring green app theme", bundle: .module),
        order: 124,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
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
