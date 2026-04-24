import Foundation
import MagicKit

actor ThemeOrchardPlugin: SuperPlugin {
    static let id: String = "orchard"
    static let displayName: String = "Orchard"
    static let description: String = "Orchard red app theme"
    static let iconName: String = "applelogo"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 128 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(appTheme: OrchardTheme(), editorThemeId: "github-dark", order: 90)
        ]
    }
}
