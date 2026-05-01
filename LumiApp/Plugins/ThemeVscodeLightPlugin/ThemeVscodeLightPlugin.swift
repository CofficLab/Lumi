import Foundation
import MagicKit

actor ThemeVscodeLightPlugin: SuperPlugin {
    static let id: String = "vscode-light"
    static let displayName: String = "VS Code 亮色"
    static let description: String = "Visual Studio Code Light+ IDE theme"
    static let iconName: String = "terminal"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 130 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: VscodeLightTheme(),
                editorThemeId: "vscode-light",
                editorThemeContributor: VscodeLightSuperEditorThemeContributor(),
                order: 95
            )
        ]
    }
}
