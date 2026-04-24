import Foundation
import MagicKit

actor ThemeNebulaPlugin: SuperPlugin {
    static let id: String = "nebula"
    static let displayName: String = "Nebula"
    static let description: String = "Nebula pink app theme"
    static let iconName: String = "sparkle.magnifyingglass"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 122 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(appTheme: NebulaTheme(), editorThemeId: "dracula", order: 30)
        ]
    }
}
