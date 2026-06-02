import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeDraculaPlugin: SuperPlugin {
    public static let shared = ThemeDraculaPlugin()
    public static let id: String = "dracula"
    public static let displayName: String = "Dracula"
    public static let description: String = "Dracula Official dark theme"
    public static let iconName: String = "moon.stars.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 132 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: DraculaTheme(),
                editorThemeId: "dracula",
                editorThemeContributor: DraculaSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "dracula-file-icons",
                    displayName: "Dracula File Icons",
                    defaultFile: .systemImage("doc.fill"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
                    extraFileNames: [
                        "license": .systemImage("checkmark.seal.fill"),
                        "license.md": .systemImage("checkmark.seal.fill"),
                        "license.txt": .systemImage("checkmark.seal.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(DraculaSuperEditorThemeContributor())
    }

}

enum PluginThemeDraculaResources {
    static let bundle = Bundle.module
}
