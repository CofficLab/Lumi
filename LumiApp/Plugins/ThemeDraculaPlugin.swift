import EditorService
import LumiUI
import PluginThemeDracula

actor ThemeDraculaPlugin: SuperPlugin {
    static let shared = ThemeDraculaPlugin()
    static let id: String = PluginThemeDracula.ThemeDraculaPlugin.id
    static let displayName: String = PluginThemeDracula.ThemeDraculaPlugin.displayName
    static let description: String = PluginThemeDracula.ThemeDraculaPlugin.description
    static let iconName: String = PluginThemeDracula.ThemeDraculaPlugin.iconName
    static let isConfigurable: Bool = PluginThemeDracula.ThemeDraculaPlugin.isConfigurable
    static let enable: Bool = PluginThemeDracula.ThemeDraculaPlugin.enable
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeDracula.ThemeDraculaPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeDracula.ThemeDraculaPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeDracula.ThemeDraculaPlugin.shared.registerEditorExtensions(into: registry)
    }
}
