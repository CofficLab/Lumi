import Foundation
import MagicKit

actor ThemeSummerPlugin: SuperPlugin {
    static let id: String = "summer"
    static let displayName: String = "Summer"
    static let description: String = "Summer blue app theme"
    static let iconName: String = "sun.max.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 125 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer",
                editorThemeContributor: SummerSuperEditorThemeContributor(),
                order: 60
            )
        ]
    }
}
