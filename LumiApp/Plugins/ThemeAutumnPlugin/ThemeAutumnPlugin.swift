import Foundation

actor ThemeAutumnPlugin: SuperPlugin {
    static let shared = ThemeAutumnPlugin()
    static let id: String = "autumn"
    static let displayName: String = "Autumn"
    static let description: String = "Autumn orange app theme"
    static let iconName: String = "leaf"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 126 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn",
                editorThemeContributor: AutumnSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "autumn-file-icons",
                    displayName: "Autumn File Icons",
                    defaultFile: .systemImage("doc.text.image"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
                    extraExtensions: [
                        "yaml": .systemImage("list.bullet.rectangle"),
                        "yml": .systemImage("list.bullet.rectangle"),
                        "plist": .systemImage("gearshape.2"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(AutumnSuperEditorThemeContributor())
    }

}
