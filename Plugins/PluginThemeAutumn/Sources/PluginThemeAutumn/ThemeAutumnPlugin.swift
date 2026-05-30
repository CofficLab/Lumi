import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeAutumnPlugin: SuperPlugin {
    public static let shared = ThemeAutumnPlugin()
    public static let id: String = "autumn"
    public static let displayName: String = "Autumn"
    public static let description: String = "Autumn orange app theme"
    public static let iconName: String = "leaf"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 126 }

    nonisolated public var instanceLabel: String { Self.id }

    private init() {}

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: AutumnTheme(),
                editorThemeId: "autumn",
                editorThemeContributor: AutumnSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "autumn-file-icons",
                    displayName: "Autumn File Icons",
                    defaultFile: .systemImage("doc.text.image"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
                    extraExtensions: [
                        "yaml": .systemImage("list.bullet.rectangle"),
                        "yml": .systemImage("list.bullet.rectangle"),
                        "plist": .systemImage("gearshape.2"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(AutumnSuperEditorThemeContributor())
    }

}

enum PluginThemeAutumnResources {
    static let bundle = Bundle.module
}
