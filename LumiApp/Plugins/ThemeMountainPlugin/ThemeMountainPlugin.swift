import Foundation
import MagicKit

actor ThemeMountainPlugin: SuperPlugin {
    static let id: String = "mountain"
    static let displayName: String = "Mountain"
    static let description: String = "Mountain gray app theme"
    static let iconName: String = "mountain.2.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 129 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain",
                editorThemeContributor: MountainEditorThemeContributor(),
                order: 100
            )
        ]
    }
}
