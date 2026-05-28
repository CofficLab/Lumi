import AgentToolKit
import EditorService
import LumiUI
import PluginThemeNebula

actor ThemeNebulaPlugin: SuperPlugin {
    static let shared = ThemeNebulaPlugin()
    static let id: String = PluginThemeNebula.ThemeNebulaPlugin.id
    static let displayName: String = PluginThemeNebula.ThemeNebulaPlugin.displayName
    static let description: String = PluginThemeNebula.ThemeNebulaPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeNebula.ThemeNebulaPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeNebula.ThemeNebulaPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeNebula.ThemeNebulaPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeNebula.ThemeNebulaPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeNebula.ThemeNebulaPlugin.shared.registerEditorExtensions(into: registry)
    }
}
