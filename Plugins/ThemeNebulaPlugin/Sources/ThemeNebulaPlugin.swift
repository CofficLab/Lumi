import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeNebulaPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = ThemeNebulaPlugin()
    public static let id: String = "nebula"
    public static let displayName: String = "星云粉"
    public static let description: String = "浪漫的星云粉，柔和而温暖"
    public static let iconName: String = "cloud.moon.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 122 }

    public nonisolated var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: NebulaTheme(),
                editorThemeId: "nebula",
                editorThemeContributor: NebulaSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "nebula-file-icons",
                    displayName: "Nebula File Icons",
                    defaultFile: .systemImage("circle.hexagongrid"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
                    extraExtensions: [
                        "swift": .systemImage("atom"),
                        "json": .systemImage("circle.hexagongrid.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(NebulaSuperEditorThemeContributor())
    }
}

public enum ThemeNebulaPluginResources {
    public static let bundle = Bundle.module
}
