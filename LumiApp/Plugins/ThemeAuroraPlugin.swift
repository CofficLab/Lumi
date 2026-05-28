import EditorService
import LumiUI
import PluginThemeAurora

actor ThemeAuroraPlugin: SuperPlugin {
    static let shared = ThemeAuroraPlugin()
    static let id: String = PluginThemeAurora.ThemeAuroraPlugin.id
    static let displayName: String = PluginThemeAurora.ThemeAuroraPlugin.displayName
    static let description: String = PluginThemeAurora.ThemeAuroraPlugin.description
    static let iconName: String = PluginThemeAurora.ThemeAuroraPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeAurora.ThemeAuroraPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeAurora.ThemeAuroraPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeAurora.ThemeAuroraPlugin.shared.registerEditorExtensions(into: registry)
    }
}
