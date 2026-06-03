import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeSummerPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeSummerPlugin()
    public static let id: String = "summer"
    public static let displayName: String = "Summer"
    public static let description: String = "Summer blue app theme"
    public static let iconName: String = "sun.max.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 125 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: SummerTheme(),
                editorThemeId: "summer",
                editorThemeContributor: SummerSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "summer-file-icons",
                    displayName: "Summer File Icons",
                    defaultFile: .systemImage("sun.max"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder.badge.person.crop", "folder.fill.badge.person.crop"),
                    extraExtensions: [
                        "png": .systemImage("sun.max"),
                        "jpg": .systemImage("sun.max"),
                        "jpeg": .systemImage("sun.max"),
                        "pdf": .systemImage("doc.richtext.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(SummerSuperEditorThemeContributor())
    }

}
