import Foundation

@objc(LumiThemeNordEditorPlugin)
@MainActor
final class ThemeNordEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.nord"
    let displayName: String = String(localized: "Nord Theme", table: "ThemeNordEditor")
    override var description: String { String(localized: "Arctic-inspired dark theme with calm, frosty blue tones", table: "ThemeNordEditor") }
    let order: Int = 110
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeNordContributor())
    }
}
