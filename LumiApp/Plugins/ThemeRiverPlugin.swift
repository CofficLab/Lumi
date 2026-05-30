import AgentToolKit
import EditorService
import LumiUI
import PluginThemeRiver

actor ThemeRiverPlugin: SuperPlugin {
    static let shared = ThemeRiverPlugin()
    static let id: String = PluginThemeRiver.ThemeRiverPlugin.id
    static let displayName: String = PluginThemeRiver.ThemeRiverPlugin.displayName
    static let description: String = PluginThemeRiver.ThemeRiverPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeRiver.ThemeRiverPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeRiver.ThemeRiverPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeRiver.ThemeRiverPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeRiver.ThemeRiverPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeRiver.ThemeRiverPlugin.shared.registerEditorExtensions(into: registry)
    }
}
