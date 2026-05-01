import Foundation
import MagicKit

actor ThemeMidnightPlugin: SuperPlugin {
    static let id: String = "midnight"
    static let displayName: String = "Midnight"
    static let description: String = "Deep dark blue color scheme"
    static let iconName: String = "moon.stars.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 120 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight",
                editorThemeContributor: MidnightEditorThemeContributor(),
                order: 10
            )
        ]
    }
}
