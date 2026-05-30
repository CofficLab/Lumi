import AgentToolKit
import EditorService
import LumiUI
import PluginThemeVscodeDark

actor ThemeVscodeDarkPlugin: SuperPlugin {
    static let shared = ThemeVscodeDarkPlugin()
    static let id: String = PluginThemeVscodeDark.ThemeVscodeDarkPlugin.id
    static let displayName: String = PluginThemeVscodeDark.ThemeVscodeDarkPlugin.displayName
    static let description: String = PluginThemeVscodeDark.ThemeVscodeDarkPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeVscodeDark.ThemeVscodeDarkPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeVscodeDark.ThemeVscodeDarkPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeVscodeDark.ThemeVscodeDarkPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeVscodeDark.ThemeVscodeDarkPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeVscodeDark.ThemeVscodeDarkPlugin.shared.registerEditorExtensions(into: registry)
    }
}
