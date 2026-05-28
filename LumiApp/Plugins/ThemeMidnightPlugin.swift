import EditorService
import LumiUI
import PluginThemeMidnight

actor ThemeMidnightPlugin: SuperPlugin {
    static let shared = ThemeMidnightPlugin()
    static let id: String = PluginThemeMidnight.ThemeMidnightPlugin.id
    static let displayName: String = PluginThemeMidnight.ThemeMidnightPlugin.displayName
    static let description: String = PluginThemeMidnight.ThemeMidnightPlugin.description
    static let iconName: String = PluginThemeMidnight.ThemeMidnightPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeMidnight.ThemeMidnightPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeMidnight.ThemeMidnightPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeMidnight.ThemeMidnightPlugin.shared.registerEditorExtensions(into: registry)
    }
}
