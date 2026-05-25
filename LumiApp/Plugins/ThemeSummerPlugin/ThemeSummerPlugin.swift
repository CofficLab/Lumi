import Foundation

actor ThemeSummerPlugin: SuperPlugin {
    static let shared = ThemeSummerPlugin()
    static let id: String = "summer"
    static let displayName: String = "Summer"
    static let description: String = "Summer blue app theme"
    static let iconName: String = "sun.max.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var category: PluginCategory { .theme }
    static var order: Int { 125 }

    nonisolated var instanceLabel: String { Self.id }

    @MainActor
    func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer",
                editorThemeContributor: SummerSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "summer-file-icons",
                    displayName: "Summer File Icons",
                    defaultFile: .systemImage("sun.max"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.person.crop", "folder.fill.badge.person.crop"),
                    extraExtensions: [
                        "png": .systemImage("sun.max"),
                        "jpg": .systemImage("sun.max"),
                        "jpeg": .systemImage("sun.max"),
                        "pdf": .systemImage("doc.richtext.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(SummerSuperEditorThemeContributor())
    }

}
