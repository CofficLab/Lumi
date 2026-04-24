import Foundation

@objc(LumiThemeOneDarkEditorPlugin)
@MainActor
final class ThemeOneDarkEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.one-dark"
    let displayName: String = String(localized: "One Dark Theme", table: "ThemeOneDarkEditor")
    override var description: String { String(localized: "Atom-inspired dark theme with soft, comfortable tones", table: "ThemeOneDarkEditor") }
    let order: Int = 108
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeOneDarkContributor())
    }
}
