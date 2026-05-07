import Foundation
import MagicKit

actor ThemeVscodeDarkPlugin: SuperPlugin {
    static let id: String = "vscode-dark"
    static let displayName: String = "VS Code 深色"
    static let description: String = "Visual Studio Code Dark+ IDE theme"
    static let iconName: String = "terminal.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 129 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiThemeContribution] {
        [
            LumiThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark",
                editorThemeContributor: VscodeDarkSuperEditorThemeContributor(),
                order: 90
            )
        ]
    }
}
