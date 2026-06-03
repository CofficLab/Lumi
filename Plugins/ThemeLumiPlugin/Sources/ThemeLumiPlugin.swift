import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeLumiPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeLumiPlugin()
    public static let id: String = "lumi"
    public static let displayName: String = "Lumi"
    public static let description: String = "Balanced default theme that adapts to system appearance"
    public static let iconName: String = "circle.hexagonpath.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 119 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: LumiTheme(),
                editorThemeId: "lumi-dark",
                editorThemeContributor: LumiDarkEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "lumi-file-icons",
                    displayName: "Lumi File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "md": .systemImage("text.alignleft"),
                        "json": .systemImage("curlybraces"),
                    ]
                )
            ),
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(LumiDarkEditorThemeContributor())
        registry.registerThemeContributor(LumiLightEditorThemeContributor())
    }
}
