import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeMidnightPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeMidnightPlugin()
    public static let id: String = "midnight"
    public static let displayName: String = "Midnight"
    public static let description: String = "Deep dark blue color scheme"
    public static let iconName: String = "moon.stars.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 120 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: MidnightTheme(),
                editorThemeId: "midnight",
                editorThemeContributor: MidnightSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "midnight-file-icons",
                    displayName: "Midnight File Icons",
                    defaultFile: .systemImage("doc"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "md": .systemImage("text.alignleft"),
                        "markdown": .systemImage("text.alignleft"),
                        "json": .systemImage("curlybraces.square"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(MidnightSuperEditorThemeContributor())
    }

}

enum ThemeMidnightPluginResources {
    static let bundle = Bundle.module
}
