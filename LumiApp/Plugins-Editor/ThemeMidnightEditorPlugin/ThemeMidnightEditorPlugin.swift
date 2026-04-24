import Foundation

@objc(LumiThemeMidnightEditorPlugin)
@MainActor
final class ThemeMidnightEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.midnight"
    let displayName: String = String(localized: "Midnight Theme", table: "ThemeMidnightEditor")
    override var description: String { String(localized: "Deep dark blue color scheme", table: "ThemeMidnightEditor") }
    let order: Int = 102
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeMidnightContributor())
    }
}
