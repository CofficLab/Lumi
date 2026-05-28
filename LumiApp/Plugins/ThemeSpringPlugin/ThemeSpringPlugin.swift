import Foundation

actor ThemeSpringPlugin: SuperPlugin {
    static let shared = ThemeSpringPlugin()
    static let id: String = "spring"
    static let displayName: String = "Spring"
    static let description: String = "Spring green app theme"
    static let iconName: String = "leaf.fill"
    static var category: PluginCategory { .theme }
    static var order: Int { 124 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SpringTheme(),
                editorThemeId: "spring",
                editorThemeContributor: SpringSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "spring-file-icons",
                    displayName: "Spring File Icons",
                    defaultFile: .systemImage("leaf"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.plus", "folder.fill.badge.plus"),
                    extraExtensions: [
                        "md": .systemImage("leaf"),
                        "markdown": .systemImage("leaf"),
                        "txt": .systemImage("doc.text"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(SpringSuperEditorThemeContributor())
    }

}
