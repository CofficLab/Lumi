import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeOneDarkPlugin: SuperPlugin {
    public static let shared = ThemeOneDarkPlugin()
    public static let id: String = "one-dark"
    public static let displayName: String = "One Dark"
    public static let description: String = "Atom One Dark classic dark theme"
    public static let iconName: String = "circle.hexagongrid"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 131 }

    public nonisolated var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OneDarkTheme(),
                editorThemeId: "one-dark",
                editorThemeContributor: OneDarkSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "one-dark-file-icons",
                    displayName: "One Dark File Icons",
                    defaultFile: .systemImage("doc.circle"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.circle", "folder.circle.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "json": .systemImage("curlybraces"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(OneDarkSuperEditorThemeContributor())
    }
}

public enum ThemeOneDarkPluginResources {
    public static let bundle = Bundle.module
}
