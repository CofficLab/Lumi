import LumiCoreKit
import LumiUI

public enum ThemeVscodeDarkPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.vscode-dark",
        displayName: "VS Code 深色 Theme",
        description: "Visual Studio Code Dark+ IDE theme",
        order: 129
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark"
            )
        ]
    }
}
