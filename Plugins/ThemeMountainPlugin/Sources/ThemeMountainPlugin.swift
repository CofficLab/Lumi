import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeMountainPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = ThemeMountainPlugin()
    public static let id: String = "mountain"
    public static let displayName: String = "Mountain"
    public static let description: String = "Mountain gray app theme"
    public static let iconName: String = "mountain.2.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 129 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MountainTheme(),
                editorThemeId: "mountain",
                editorThemeContributor: MountainSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "mountain-file-icons",
                    displayName: "Mountain File Icons",
                    defaultFile: .systemImage("mountain.2"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.minus", "folder.fill.badge.minus"),
                    extraFileNames: [
                        "makefile": .systemImage("hammer.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(MountainSuperEditorThemeContributor())
    }

}

enum ThemeMountainPluginResources {
    static let bundle = Bundle.module
}
