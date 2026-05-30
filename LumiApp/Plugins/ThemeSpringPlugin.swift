import AgentToolKit
import EditorService
import LumiUI
import PluginThemeSpring

actor ThemeSpringPlugin: SuperPlugin {
    static let shared = ThemeSpringPlugin()
    static let id: String = PluginThemeSpring.ThemeSpringPlugin.id
    static let displayName: String = PluginThemeSpring.ThemeSpringPlugin.displayName
    static let description: String = PluginThemeSpring.ThemeSpringPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeSpring.ThemeSpringPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeSpring.ThemeSpringPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeSpring.ThemeSpringPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeSpring.ThemeSpringPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeSpring.ThemeSpringPlugin.shared.registerEditorExtensions(into: registry)
    }
}
