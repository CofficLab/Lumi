import Foundation
import MagicKit

actor ThemeNebulaPlugin: SuperPlugin {
    static let id: String = "nebula"
    static let displayName: String = "星云粉"
    static let description: String = "浪漫的星云粉，柔和而温暖"
    static let iconName: String = "cloud.moon.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 122 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula",
                editorThemeContributor: NebulaSuperEditorThemeContributor(),
                order: 30
            )
        ]
    }
}
