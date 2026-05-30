import AgentToolKit
import EditorService
import LumiUI
import PluginThemeVoid

actor ThemeVoidPlugin: SuperPlugin {
    static let shared = ThemeVoidPlugin()
    static let id: String = PluginThemeVoid.ThemeVoidPlugin.id
    static let displayName: String = PluginThemeVoid.ThemeVoidPlugin.displayName
    static let description: String = PluginThemeVoid.ThemeVoidPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeVoid.ThemeVoidPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeVoid.ThemeVoidPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeVoid.ThemeVoidPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeVoid.ThemeVoidPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeVoid.ThemeVoidPlugin.shared.registerEditorExtensions(into: registry)
    }
}
