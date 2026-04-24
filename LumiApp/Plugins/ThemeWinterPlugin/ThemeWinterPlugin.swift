import Foundation
import MagicKit

actor ThemeWinterPlugin: SuperPlugin {
    static let id: String = "winter"
    static let displayName: String = "Winter"
    static let description: String = "Winter cool app theme"
    static let iconName: String = "snowflake"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 127 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "solarized-dark",
                editorThemeContributor: SolarizedDarkEditorThemeContributor(),
                order: 80
            )
        ]
    }
}
