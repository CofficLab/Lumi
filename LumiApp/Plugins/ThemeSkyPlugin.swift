import AgentToolKit
import EditorService
import LumiUI
import PluginThemeSky

actor ThemeSkyPlugin: SuperPlugin {
    static let shared = ThemeSkyPlugin()
    static let id: String = PluginThemeSky.ThemeSkyPlugin.id
    static let displayName: String = PluginThemeSky.ThemeSkyPlugin.displayName
    static let description: String = PluginThemeSky.ThemeSkyPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeSky.ThemeSkyPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeSky.ThemeSkyPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeSky.ThemeSkyPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeSky.ThemeSkyPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeSky.ThemeSkyPlugin.shared.registerEditorExtensions(into: registry)
    }
}
