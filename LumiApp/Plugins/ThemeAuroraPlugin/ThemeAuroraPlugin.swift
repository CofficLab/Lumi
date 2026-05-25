import Foundation

actor ThemeAuroraPlugin: SuperPlugin {
    static let shared = ThemeAuroraPlugin()
    static let id: String = "aurora"
    static let displayName: String = "Aurora"
    static let description: String = "Aurora purple app theme"
    static let iconName: String = "sparkles"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 121 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AuroraTheme(),
                editorThemeId: "aurora",
                editorThemeContributor: AuroraSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "aurora-file-icons",
                    displayName: "Aurora File Icons",
                    defaultFile: .systemImage("sparkles"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.plus", "folder.fill.badge.plus"),
                    extraExtensions: [
                        "png": .systemImage("photo.on.rectangle"),
                        "jpg": .systemImage("photo.on.rectangle"),
                        "jpeg": .systemImage("photo.on.rectangle"),
                        "svg": .systemImage("camera.filters"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(AuroraSuperEditorThemeContributor())
    }

}
