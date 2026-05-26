import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeAuroraPlugin: SuperPlugin {
    public static let shared = ThemeAuroraPlugin()
    public static let id: String = "aurora"
    public static let displayName: String = "Aurora"
    public static let description: String = "Aurora purple app theme"
    public static let iconName: String = "sparkles"
    public static let isConfigurable: Bool = false
    public static let enable: Bool = true
    public static var category: PluginCategory { .theme }
    public static var order: Int { 121 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
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
    public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(AuroraSuperEditorThemeContributor())
    }

}
