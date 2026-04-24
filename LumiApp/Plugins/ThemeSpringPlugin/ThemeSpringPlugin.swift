import Foundation
import MagicKit

actor ThemeSpringPlugin: SuperPlugin {
    static let id: String = "spring"
    static let displayName: String = "Spring"
    static let description: String = "Spring green app theme"
    static let iconName: String = "leaf.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 124 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: SpringTheme(),
                editorThemeId: "spring",
                editorThemeContributor: SpringEditorThemeContributor(),
                order: 50
            )
        ]
    }
}
