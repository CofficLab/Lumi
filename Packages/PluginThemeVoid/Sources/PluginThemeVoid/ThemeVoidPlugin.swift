import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeVoidPlugin: SuperPlugin {
    public static let shared = ThemeVoidPlugin()
    public static let id: String = "void"
    public static let displayName: String = "虚空深黑"
    public static let description: String = "纯粹的虚空黑，深邃而神秘"
    public static let iconName: String = "circle.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 123 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VoidTheme(),
                editorThemeId: "void",
                editorThemeContributor: VoidSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "void-file-icons",
                    displayName: "Void File Icons",
                    defaultFile: .systemImage("doc.fill"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("archivebox", "archivebox.fill"),
                    extraFileNames: [
                        "readme": .systemImage("doc.text.fill"),
                        "readme.md": .systemImage("doc.text.fill"),
                        "readme.markdown": .systemImage("doc.text.fill"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        registry.registerThemeContributor(VoidSuperEditorThemeContributor())
    }

}
