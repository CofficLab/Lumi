import EditorService
import LumiUI
import PluginThemeAutumn

actor ThemeAutumnPlugin: SuperPlugin {
    static let shared = ThemeAutumnPlugin()
    static let id: String = PluginThemeAutumn.ThemeAutumnPlugin.id
    static let displayName: String = PluginThemeAutumn.ThemeAutumnPlugin.displayName
    static let description: String = PluginThemeAutumn.ThemeAutumnPlugin.description
    static let iconName: String = PluginThemeAutumn.ThemeAutumnPlugin.iconName
    static let isConfigurable: Bool = PluginThemeAutumn.ThemeAutumnPlugin.isConfigurable
    static let enable: Bool = PluginThemeAutumn.ThemeAutumnPlugin.enable
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeAutumn.ThemeAutumnPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeAutumn.ThemeAutumnPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeAutumn.ThemeAutumnPlugin.shared.registerEditorExtensions(into: registry)
    }
}
