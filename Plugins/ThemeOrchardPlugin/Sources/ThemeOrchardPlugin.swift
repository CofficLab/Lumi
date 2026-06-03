import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeOrchardPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = ThemeOrchardPlugin()
    public static let id: String = "orchard"
    public static let displayName: String = "Orchard"
    public static let description: String = "Orchard red app theme"
    public static let iconName: String = "applelogo"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 128 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: OrchardTheme(),
                editorThemeId: "orchard",
                editorThemeContributor: OrchardSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "orchard-file-icons",
                    displayName: "Orchard File Icons",
                    defaultFile: .systemImage("apple.logo"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("tray", "tray.fill"),
                    extraExtensions: [
                        "swift": .systemImage("swift"),
                        "h": .systemImage("h.square"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(OrchardSuperEditorThemeContributor())
    }

}
