import Foundation
import MagicKit

actor ThemeAutumnPlugin: SuperPlugin {
    static let id: String = "autumn"
    static let displayName: String = "Autumn"
    static let description: String = "Autumn orange app theme"
    static let iconName: String = "leaf"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 126 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn",
                editorThemeContributor: AutumnSuperEditorThemeContributor(),
                order: 70
            )
        ]
    }
}
