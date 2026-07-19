import LumiKernel
import LumiUI
import os

public enum ThemeNebulaPlugin: LumiPlugin, LumiUIThemeProviding {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme.nebula")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme.nebula",
        displayName: LumiPluginLocalization.string("星云粉 Theme", bundle: .module),
        description: LumiPluginLocalization.string("浪漫的星云粉，柔和而温暖", bundle: .module),
        order: 122,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func themeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula"
            )
        ]
    }
}
