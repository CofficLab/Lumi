import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeSpringPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeSpringPlugin()
    public static let id: String = "spring"
    public static let displayName: String = "Spring"
    public static let description: String = "Spring green app theme"
    public static let iconName: String = "leaf.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 124 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
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
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(SpringSuperEditorThemeContributor())
    }

}
