import Foundation
import MagicKit

actor ThemeVoidPlugin: SuperPlugin {
    static let id: String = "void"
    static let displayName: String = "Void"
    static let description: String = "Void deep dark app theme"
    static let iconName: String = "moonphase.new.moon"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 123 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "high-contrast",
                editorThemeContributor: HighContrastEditorThemeContributor(),
                order: 40
            )
        ]
    }
}
