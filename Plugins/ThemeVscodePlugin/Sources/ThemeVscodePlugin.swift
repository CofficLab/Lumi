import LumiCoreKit
import LumiUI

public enum ThemeVscodePlugin: LumiPlugin, LumiUIThemeProviding {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.vscode",
        displayName: LumiPluginLocalization.string("VS Code Theme", bundle: .module),
        description: LumiPluginLocalization.string("VS Code Dark+, Light+ and Auto themes", bundle: .module),
        order: 129,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeAutoTheme(),
                editorThemeId: "vscode-auto"
            ),
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark"
            ),
            LumiUIThemeContribution(
                appTheme: VscodeLightTheme(),
                editorThemeId: "vscode-light"
            ),
        ]
    }
}
