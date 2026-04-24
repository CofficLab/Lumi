import Foundation
import MagicKit

actor ThemeRiverPlugin: SuperPlugin {
    static let id: String = "river"
    static let displayName: String = "River"
    static let description: String = "River cyan app theme"
    static let iconName: String = "water.waves"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 130 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: RiverTheme(),
                editorThemeId: "xcode-dark",
                editorThemeContributor: XcodeDarkEditorThemeContributor(),
                order: 110
            )
        ]
    }
}
