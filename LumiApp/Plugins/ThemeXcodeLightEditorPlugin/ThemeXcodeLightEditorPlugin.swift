import Foundation

@objc(LumiThemeXcodeLightEditorPlugin)
@MainActor
final class ThemeXcodeLightEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.theme.xcode-light"
    let displayName: String = String(localized: "Xcode Light Theme", table: "ThemeXcodeLightEditor")
    override var description: String { String(localized: "Classic Xcode light color scheme", table: "ThemeXcodeLightEditor") }
    let order: Int = 101
    let isConfigurable: Bool = false
    let isEnabledByDefault: Bool = true

    func register(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(ThemeXcodeLightContributor())
    }
}
