import Foundation

@objc(LumiThemeMonokaiEditorPlugin)
@MainActor
final class ThemeMonokaiEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.monokai"
    let displayName: String = String(localized: "Monokai Theme", table: "ThemeMonokaiEditor")
    override var description: String { String(localized: "Classic dark theme with vibrant warm colors", table: "ThemeMonokaiEditor") }
    let order: Int = 107
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeMonokaiContributor())
    }
}
