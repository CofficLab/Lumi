import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeSkyPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = ThemeSkyPlugin()
    public static let id: String = "sky"
    public static let displayName: String = "Sky"
    public static let description: String = "Sky inspired app theme that adapts to system appearance"
    public static let iconName: String = "cloud.sun.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 120 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SkyTheme(),
                editorThemeId: "sky-dark",
                editorThemeContributor: SkyDarkEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "sky-file-icons",
                    displayName: "Sky File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "md": .systemImage("cloud"),
                        "markdown": .systemImage("cloud"),
                        "json": .systemImage("curlybraces"),
                        "png": .systemImage("photo"),
                        "jpg": .systemImage("photo"),
                        "jpeg": .systemImage("photo"),
                    ]
                )
            ),
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(SkyDarkEditorThemeContributor())
        registry.registerThemeContributor(SkyLightEditorThemeContributor())
    }
}
