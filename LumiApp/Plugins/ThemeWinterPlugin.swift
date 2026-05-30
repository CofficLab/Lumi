import AgentToolKit
import EditorService
import LumiUI
import PluginThemeWinter

actor ThemeWinterPlugin: SuperPlugin {
    static let shared = ThemeWinterPlugin()
    static let id: String = PluginThemeWinter.ThemeWinterPlugin.id
    static let displayName: String = PluginThemeWinter.ThemeWinterPlugin.displayName
    static let description: String = PluginThemeWinter.ThemeWinterPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeWinter.ThemeWinterPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeWinter.ThemeWinterPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeWinter.ThemeWinterPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeWinter.ThemeWinterPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeWinter.ThemeWinterPlugin.shared.registerEditorExtensions(into: registry)
    }
}
