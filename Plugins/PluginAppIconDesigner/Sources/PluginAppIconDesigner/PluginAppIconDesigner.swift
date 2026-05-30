import Foundation
import AgentToolKit
import LumiCoreKit
import SwiftUI

public actor AppIconDesignerPlugin: SuperPlugin {
    public static let id = "AppIconDesigner"
    public static var displayName: String { AppIconDesignerLocalization.string("App Icon Designer") }
    public static var description: String {
        AppIconDesignerLocalization.string("Design vector app icons with manual drawing tools, layer controls, and Xcode icon set export.")
    }
    public static func description(for language: LanguagePreference) -> String {
        AppIconDesignerLocalization.string(
            "Design vector app icons with manual drawing tools, layer controls, and Xcode icon set export.",
            for: language
        )
    }
    public static let iconName = "app.dashed"
    public static var order: Int { 79 }
    public static var category: PluginCategory { .general }
    public static let policy: PluginPolicy = .alwaysOn

    public static let shared = AppIconDesignerPlugin()

    private init() {}

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(AppIconDesignerView())
        }
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            ApplyIconPresetTool(),
            CreateIconDocumentTool(),
            SetIconBackgroundTool(),
            AddIconShapeTool(),
            UpdateIconLayerTool(),
            UpdateIconShapeTool(),
            LintIconDocumentTool(),
            SaveIconDocumentTool(),
            LoadIconDocumentTool(),
            ExportIconSVGTool(),
            RegisterAppIconArtifactTool(),
            ExportAppIconTool(),
        ]
    }
}
