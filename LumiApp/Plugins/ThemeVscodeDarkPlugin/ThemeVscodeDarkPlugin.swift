import Foundation

actor ThemeVscodeDarkPlugin: SuperPlugin {
    static let shared = ThemeVscodeDarkPlugin()
    static let id: String = "vscode-dark"
    static let displayName: String = "VS Code 深色"
    static let description: String = "Visual Studio Code Dark+ IDE theme"
    static let iconName: String = "terminal.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 129 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark",
                editorThemeContributor: VscodeDarkSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "vscode-dark-file-icons",
                    displayName: "VS Code Dark File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraFileNames: [
                        "package.json": .systemImage("shippingbox.fill"),
                        "package.swift": .systemImage("swift"),
                    ],
                    extraExtensions: [
                        "json": .systemImage("curlybraces.square.fill"),
                        "md": .systemImage("doc.richtext"),
                        "markdown": .systemImage("doc.richtext"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VscodeDarkSuperEditorThemeContributor())
    }

}
