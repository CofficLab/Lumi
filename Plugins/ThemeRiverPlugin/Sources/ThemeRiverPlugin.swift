import Foundation
import EditorService
import LumiCoreKit
import LumiUI

public actor ThemeRiverPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = ThemeRiverPlugin()
    public static let id: String = "river"
    public static let displayName: String = "River"
    public static let description: String = "River cyan app theme"
    public static let iconName: String = "water.waves"
    public static var category: PluginCategory { .theme }
    public static var order: Int { 130 }

    nonisolated public var instanceLabel: String { Self.id }

    @MainActor
    public func addThemeContributions() -> [LumiUIThemeContribution] {
        [
            LumiUIThemeContribution(
                appTheme: RiverTheme(),
                editorThemeId: "river",
                editorThemeContributor: RiverSuperEditorThemeContributor(),
                fileIconThemeContributor: LumiFileIconThemeBuilder.make(
                    id: "river-file-icons",
                    displayName: "River File Icons",
                    defaultFile: .systemImage("water.waves"),
                    defaultFolder: LumiFileIconThemeBuilder.folder("externaldrive", "externaldrive.fill"),
                    extraExtensions: [
                        "xml": .systemImage("point.3.connected.trianglepath.dotted"),
                        "json": .systemImage("point.3.connected.trianglepath.dotted"),
                    ]
                )
            )
        ]
    }

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerThemeContributor(RiverSuperEditorThemeContributor())
    }

}
