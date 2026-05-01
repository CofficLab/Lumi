import Foundation
import MagicKit

actor ThemeAuroraPlugin: SuperPlugin {
    static let id: String = "aurora"
    static let displayName: String = "Aurora"
    static let description: String = "Aurora purple app theme"
    static let iconName: String = "sparkles"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 121 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora",
                editorThemeContributor: AuroraSuperEditorThemeContributor(),
                order: 20
            )
        ]
    }
}
