import LumiCoreKit
import LumiUI
import os

public enum ThemeOneDarkPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.one-dark")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.one-dark",
        displayName: LumiPluginLocalization.string("One Dark Theme", bundle: .module),
        description: LumiPluginLocalization.string("Atom One Dark classic dark theme", bundle: .module),
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
