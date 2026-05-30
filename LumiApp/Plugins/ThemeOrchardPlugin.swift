import AgentToolKit
import EditorService
import LumiUI
import PluginThemeOrchard

actor ThemeOrchardPlugin: SuperPlugin {
    static let shared = ThemeOrchardPlugin()
    static let id: String = PluginThemeOrchard.ThemeOrchardPlugin.id
    static let displayName: String = PluginThemeOrchard.ThemeOrchardPlugin.displayName
    static let description: String = PluginThemeOrchard.ThemeOrchardPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeOrchard.ThemeOrchardPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeOrchard.ThemeOrchardPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeOrchard.ThemeOrchardPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeOrchard.ThemeOrchardPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeOrchard.ThemeOrchardPlugin.shared.registerEditorExtensions(into: registry)
    }
}
