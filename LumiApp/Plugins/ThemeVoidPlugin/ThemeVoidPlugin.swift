import Foundation

actor ThemeVoidPlugin: SuperPlugin {
    static let shared = ThemeVoidPlugin()
    static let id: String = "void"
    static let displayName: String = "虚空深黑"
    static let description: String = "纯粹的虚空黑，深邃而神秘"
    static let iconName: String = "circle.fill"
    static var category: PluginCategory { .theme }
    static var order: Int { 123 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void",
                editorThemeContributor: VoidSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "void-file-icons",
                    displayName: "Void File Icons",
                    defaultFile: .systemImage("doc.fill"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("archivebox", "archivebox.fill"),
                    extraFileNames: [
                        "readme": .systemImage("doc.text.fill"),
                        "readme.md": .systemImage("doc.text.fill"),
                        "readme.markdown": .systemImage("doc.text.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VoidSuperEditorThemeContributor())
    }

}
