import AgentToolKit
import EditorService
import LumiUI
import PluginThemeSummer

actor ThemeSummerPlugin: SuperPlugin {
    static let shared = ThemeSummerPlugin()
    static let id: String = PluginThemeSummer.ThemeSummerPlugin.id
    static let displayName: String = PluginThemeSummer.ThemeSummerPlugin.displayName
    static let description: String = PluginThemeSummer.ThemeSummerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginThemeSummer.ThemeSummerPlugin.description(for: language)
    }
    static let iconName: String = PluginThemeSummer.ThemeSummerPlugin.iconName
    static var category: PluginCategory { .theme }
    static var order: Int { PluginThemeSummer.ThemeSummerPlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        PluginThemeSummer.ThemeSummerPlugin.shared.addThemeContributions()
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        PluginThemeSummer.ThemeSummerPlugin.shared.registerEditorExtensions(into: registry)
    }
}
