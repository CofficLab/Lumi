import AgentToolKit
import EditorService
import LumiUI
import PluginThemeVscodeLight

actor ThemeVscodeLightPlugin: SuperPlugin {
    static let shared = ThemeVscodeLightPlugin()
    static let id: String = PluginThemeVscodeLight.ThemeVscodeLightPlugin.id
    static let displayName: String = PluginThemeVscodeLight.ThemeVscodeLightPlugin.displayName
    static let description: String = PluginThemeVscodeLight.ThemeVscodeLightPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeVscodeLight.ThemeVscodeLightPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeVscodeLight.ThemeVscodeLightPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeVscodeLight.ThemeVscodeLightPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeVscodeLight.ThemeVscodeLightPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeVscodeLight.ThemeVscodeLightPlugin.shared.registerEditorExtensions(into: registry)
    }
}
