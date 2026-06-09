import AgentToolKit
import LumiCoreKit
import SwiftUI

public enum AppIconDesignerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "app.dashed"

    public static let info = LumiPluginInfo(
        id: "AppIconDesigner",
        displayName: AppIconDesignerLocalization.string("App Icon Designer"),
        description: AppIconDesignerLocalization.string(
            "Design vector app icons with manual drawing tools, layer controls, and Xcode icon set export."
        ),
        order: 79
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                AppIconDesignerView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            ApplyIconPresetTool().asLumiAgentTool(),
            CreateIconDocumentTool().asLumiAgentTool(),
            SetIconBackgroundTool().asLumiAgentTool(),
            AddIconShapeTool().asLumiAgentTool(),
            UpdateIconLayerTool().asLumiAgentTool(),
            UpdateIconShapeTool().asLumiAgentTool(),
            LintIconDocumentTool().asLumiAgentTool(),
            SaveIconDocumentTool().asLumiAgentTool(),
            LoadIconDocumentTool().asLumiAgentTool(),
            ExportIconSVGTool().asLumiAgentTool(),
            RegisterAppIconArtifactTool().asLumiAgentTool(),
            ExportAppIconTool().asLumiAgentTool(),
        ]
    }
}
