import EditorService
import LumiUI
import PluginThemeOneDark

actor ThemeOneDarkPlugin: SuperPlugin {
    static let shared = ThemeOneDarkPlugin()
    static let id: String = PluginThemeOneDark.ThemeOneDarkPlugin.id
    static let displayName: String = PluginThemeOneDark.ThemeOneDarkPlugin.displayName
    static let description: String = PluginThemeOneDark.ThemeOneDarkPlugin.description
    static let iconName: String = PluginThemeOneDark.ThemeOneDarkPlugin.iconName
    static let isConfigurable: Bool = PluginThemeOneDark.ThemeOneDarkPlugin.isConfigurable
    static let enable: Bool = PluginThemeOneDark.ThemeOneDarkPlugin.enable
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeOneDark.ThemeOneDarkPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeOneDark.ThemeOneDarkPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeOneDark.ThemeOneDarkPlugin.shared.registerEditorExtensions(into: registry)
    }
}
