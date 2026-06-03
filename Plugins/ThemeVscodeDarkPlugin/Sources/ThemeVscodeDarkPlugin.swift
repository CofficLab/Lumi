import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeVscodeDarkPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let shared = ThemeVscodeDarkPlugin()
    public static let id: String = "vscode-dark"
    public static let displayName: String = "VS Code 深色"
    public static let description: String = "Visual Studio Code Dark+ IDE theme"
    public static let iconName: String = "terminal.fill"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 129 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: VscodeDarkTheme(),
                editorThemeId: "vscode-dark",
                editorThemeContributor: VscodeDarkSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "vscode-dark-file-icons",
                    displayName: "VS Code Dark File Icons",
                    defaultFile: .systemImage("doc.text"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("folder", "folder.fill"),
                    extraFileNames: [
                        "package.json": .systemImage("shippingbox.fill"),
                        "package.swift": .systemImage("swift"),
                    ],
                    extraExtensions: [
                        "json": .systemImage("curlybraces.square.fill"),
                        "md": .systemImage("doc.richtext"),
                        "markdown": .systemImage("doc.richtext"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(VscodeDarkSuperEditorThemeContributor())
    }

}
