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

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "app.dashed", title: "App Icon Designer", description: "Provides App Icon Designer capabilities in Lumi."),
                .init(icon: "puzzlepiece.extension", title: "Lumi Integration", description: "Integrates App Icon Designer into the Lumi workspace"),
                .init(icon: "gearshape", title: "Configurable", description: "Enable or disable from plugin settings")
            ],
            steps: [
                "Enable App Icon Designer in plugin settings",
                "The plugin registers its contributions when enabled",
                "Use the features provided in the Lumi workspace"
            ],
            tips: [
                "Toggle the plugin off if you do not need this feature",
                "Check plugin settings for additional options"
            ]
        )
    }

}
