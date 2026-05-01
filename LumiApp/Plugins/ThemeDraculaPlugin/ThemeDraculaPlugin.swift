import Foundation
import MagicKit

actor ThemeDraculaPlugin: SuperPlugin {
    static let id: String = "dracula"
    static let displayName: String = "Dracula"
    static let description: String = "Dracula Official dark theme"
    static let iconName: String = "moon.stars.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 132 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: DraculaTheme(),
                editorThemeId: "dracula",
                editorThemeContributor: DraculaSuperEditorThemeContributor(),
                order: 105
            )
        ]
    }
}
