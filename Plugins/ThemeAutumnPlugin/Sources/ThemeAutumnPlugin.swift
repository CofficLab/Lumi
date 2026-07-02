import LumiCoreKit
import LumiUI
import os

public enum ThemeAutumnPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.autumn")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.autumn",
        displayName: LumiPluginLocalization.string("Autumn Theme", bundle: .module),
        description: LumiPluginLocalization.string("Autumn orange app theme", bundle: .module),
        order: 126
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn"
            )
        ]
    }
}
