import Foundation

@objc(LumiThemeSolarizedLightEditorPlugin)
@MainActor
final class ThemeSolarizedLightEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.solarized-light"
    let displayName: String = String(localized: "Solarized Light Theme", table: "ThemeSolarizedLightEditor")
    override var description: String { String(localized: "Solarized light color scheme", table: "ThemeSolarizedLightEditor") }
    let order: Int = 104
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeSolarizedLightContributor())
    }
}
