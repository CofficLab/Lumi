// MARK: - Theme Plugins Imports
import Foundation
import LumiCoreKit
import ActivityHeatmapPlugin
import FileLogPlugin
import LayoutPlugin
import ThemeAuroraPlugin
import ThemeAutumnPlugin
import ThemeDraculaPlugin
import ThemeGithubPlugin
import ThemeLumiPlugin
import ThemeMidnightPlugin
import ThemeMountainPlugin
import ThemeNebulaPlugin
import ThemeOneDarkPlugin
import ThemeOrchardPlugin
import ThemeRiverPlugin
import ThemeSkyPlugin
import ThemeSpringPlugin
import ThemeStatusBarPlugin
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin

// MARK: - Theme Plugins Extension

extension LumiPluginRegistry {
    /// Theme 插件数组，包含所有主题相关的插件。
    ///
    /// 包含：FileLogPlugin、LayoutPlugin、18 个 ThemeXxxPlugin、ThemeStatusBarPlugin
    public static let themePlugins: [any LumiPlugin.Type] = [
        // MARK: - Core

        FileLogPlugin.self,
        LayoutPlugin.self,

        // MARK: - Themes

        ThemeLumiPlugin.self,
        ThemeMidnightPlugin.self,
        ThemeSkyPlugin.self,
        ThemeAuroraPlugin.self,
        ThemeNebulaPlugin.self,
        ThemeVoidPlugin.self,
        ThemeSpringPlugin.self,
        ThemeSummerPlugin.self,
        ThemeAutumnPlugin.self,
        ThemeWinterPlugin.self,
        ThemeGithubPlugin.self,
        ThemeOrchardPlugin.self,
        ThemeMountainPlugin.self,
        ThemeVscodePlugin.self,
        ThemeRiverPlugin.self,
        ThemeOneDarkPlugin.self,
        ThemeDraculaPlugin.self,
        ThemeStatusBarPlugin.self,
    ]
}
