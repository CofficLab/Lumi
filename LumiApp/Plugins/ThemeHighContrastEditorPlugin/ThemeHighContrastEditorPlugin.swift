import Foundation

@objc(LumiThemeHighContrastEditorPlugin)
@MainActor
final class ThemeHighContrastEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.high-contrast"
    let displayName: String = String(localized: "High Contrast Theme", table: "ThemeHighContrastEditor")
    override var description: String { String(localized: "High contrast dark color scheme for accessibility", table: "ThemeHighContrastEditor") }
    let order: Int = 105
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeHighContrastContributor())
    }
}
