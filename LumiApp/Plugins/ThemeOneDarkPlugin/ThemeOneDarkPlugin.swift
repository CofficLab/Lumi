import Foundation
import MagicKit

actor ThemeOneDarkPlugin: SuperPlugin {
    static let id: String = "one-dark"
    static let displayName: String = "One Dark"
    static let description: String = "Atom One Dark classic dark theme"
    static let iconName: String = "circle.hexagongrid"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 131 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: OneDarkTheme(),
                editorThemeId: "one-dark",
                editorThemeContributor: OneDarkEditorThemeContributor(),
                order: 100
            )
        ]
    }
}
