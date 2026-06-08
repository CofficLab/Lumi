import LumiCoreKit
import LumiUI

public enum ThemeVscodeLightPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let category: LumiPluginCategory = .theme
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.vscode-light",
        displayName: "VS Code 亮色 Theme",
        description: "Visual Studio Code Light+ IDE theme",
        order: 130
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeLightTheme(),
                editorThemeId: "vscode-light"
            )
        ]
    }
}
