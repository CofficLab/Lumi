import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeVscodeLightPlugin: SuperPlugin {
    public static let shared = ThemeVscodeLightPlugin()
    public static let id: String = "vscode-light"
    public static let displayName: String = "VS Code 亮色"
    public static let description: String = "Visual Studio Code Light+ IDE theme"
    public static let iconName: String = "terminal"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 130 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeLightTheme(),
                editorThemeId: "vscode-light",
                editorThemeContributor: VscodeLightSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "vscode-light-file-icons",
                    displayName: "VS Code Light File Icons",
                    defaultFile: .systemImage("doc.plaintext"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "json": .systemImage("curlybraces.square"),
                        "md": .systemImage("book.pages"),
                        "markdown": .systemImage("book.pages"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VscodeLightSuperEditorThemeContributor())
    }

}
