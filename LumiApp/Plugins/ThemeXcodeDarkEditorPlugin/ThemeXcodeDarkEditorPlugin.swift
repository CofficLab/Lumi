import Foundation

@objc(LumiThemeXcodeDarkEditorPlugin)
@MainActor
final class ThemeXcodeDarkEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.xcode-dark"
    let displayName: String = String(localized: "Xcode Dark Theme", table: "ThemeXcodeDarkEditor")
    override var description: String { String(localized: "Classic Xcode dark color scheme", table: "ThemeXcodeDarkEditor") }
    let order: Int = 100
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeXcodeDarkContributor())
    }
}
