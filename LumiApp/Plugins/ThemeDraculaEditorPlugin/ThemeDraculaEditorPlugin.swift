import Foundation

@objc(LumiThemeDraculaEditorPlugin)
@MainActor
final class ThemeDraculaEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.dracula"
    let displayName: String = String(localized: "Dracula Theme", table: "ThemeDraculaEditor")
    override var description: String { String(localized: "Dark theme with vibrant pink, purple and cyan accents", table: "ThemeDraculaEditor") }
    let order: Int = 106
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeDraculaContributor())
    }
}
