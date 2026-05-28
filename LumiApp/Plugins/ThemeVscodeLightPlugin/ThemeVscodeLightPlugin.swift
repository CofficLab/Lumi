import Foundation

actor ThemeVscodeLightPlugin: SuperPlugin {
    static let shared = ThemeVscodeLightPlugin()
    static let id: String = "vscode-light"
    static let displayName: String = "VS Code 亮色"
    static let description: String = "Visual Studio Code Light+ IDE theme"
    static let iconName: String = "terminal"
    static var category: PluginCategory { .theme }
    static var order: Int { 130 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
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
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VscodeLightSuperEditorThemeContributor())
    }

}
