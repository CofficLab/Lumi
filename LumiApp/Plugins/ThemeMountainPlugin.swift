import AgentToolKit
import EditorService
import LumiUI
import PluginThemeMountain

actor ThemeMountainPlugin: SuperPlugin {
    static let shared = ThemeMountainPlugin()
    static let id: String = PluginThemeMountain.ThemeMountainPlugin.id
    static let displayName: String = PluginThemeMountain.ThemeMountainPlugin.displayName
    static let description: String = PluginThemeMountain.ThemeMountainPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeMountain.ThemeMountainPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeMountain.ThemeMountainPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeMountain.ThemeMountainPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeMountain.ThemeMountainPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeMountain.ThemeMountainPlugin.shared.registerEditorExtensions(into: registry)
    }
}
