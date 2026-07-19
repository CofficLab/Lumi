import LumiCoreKit
import LumiUI

public enum ThemeStatusBarPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.theme-status-bar",
        displayName: LumiPluginLocalization.string("Theme Status Bar", bundle: .module),
        description: LumiPluginLocalization.string("Adds a status bar theme switcher.", bundle: .module),
        order: 76,
        category: .theme,
        policy: .alwaysOn,
        stage: .beta,
    )

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        // LumiThemeServicing 不可用时显示错误视图
        guard let themeService = context.resolve(LumiThemeServicing.self) else {
            return [
                LumiStatusBarItem(
                    id: "\(info.id).error",
                    title: "Theme",
                    systemImage: "exclamationmark.triangle.fill",
                    placement: .trailing,
                    statusBarView: { ThemeStatusBarErrorView(pluginName: info.displayName) }
                )
            ]
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).switcher",
                title: "Theme",
                systemImage: "paintbrush",
                placement: .trailing,
                statusBarView: {
                    ThemeStatusBarView(themeService: themeService)
                }
            )
        ]
    }
}
