import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeWinterPlugin: SuperPlugin {
    public static let shared = ThemeWinterPlugin()
    public static let id: String = "winter"
    public static let displayName: String = "Winter"
    public static let description: String = "Winter cool app theme"
    public static let iconName: String = "snowflake"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 127 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: WinterTheme(),
                editorThemeId: "winter",
                editorThemeContributor: WinterSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "winter-file-icons",
                    displayName: "Winter File Icons",
                    defaultFile: .systemImage("snowflake"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
                    extraExtensions: [
                        "sh": .systemImage("terminal.fill"),
                        "bash": .systemImage("terminal.fill"),
                        "zsh": .systemImage("terminal.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(WinterSuperEditorThemeContributor())
    }

}
