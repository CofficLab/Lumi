import AgentToolKit
import EditorService
import LumiUI
import PluginThemeLumi

actor ThemeLumiPlugin: SuperPlugin {
    static let shared = ThemeLumiPlugin()
    static let id: String = PluginThemeLumi.ThemeLumiPlugin.id
    static let displayName: String = PluginThemeLumi.ThemeLumiPlugin.displayName
    static let description: String = PluginThemeLumi.ThemeLumiPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeLumi.ThemeLumiPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeLumi.ThemeLumiPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeLumi.ThemeLumiPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeLumi.ThemeLumiPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeLumi.ThemeLumiPlugin.shared.registerEditorExtensions(into: registry)
    }
}
