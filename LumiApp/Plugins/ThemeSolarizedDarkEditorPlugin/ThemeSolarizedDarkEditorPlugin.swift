import Foundation

@objc(LumiThemeSolarizedDarkEditorPlugin)
@MainActor
final class ThemeSolarizedDarkEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.solarized-dark"
    let displayName: String = String(localized: "Solarized Dark Theme", table: "ThemeSolarizedDarkEditor")
    override var description: String { String(localized: "Solarized dark color scheme", table: "ThemeSolarizedDarkEditor") }
    let order: Int = 103
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeSolarizedDarkContributor())
    }
}
