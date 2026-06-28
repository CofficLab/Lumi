import AgentToolKit
import LumiCoreKit
import LumiUI
import SwiftUI

public enum AppIconDesignerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
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
            icon: iconName,
            displayName: info.displayName,
            description: info.description,
            kind: .general
        )
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [LumiPluginOnboardingPage] {
        [
            LumiPluginOnboardingPage(id: "\(info.id).onboarding", order: info.order) {
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "scribble.variable",
                            title: AppIconDesignerLocalization.string("Vector drawing"),
                            description: AppIconDesignerLocalization.string("Build icons with shapes, layers, and presets")
                        ),
                        .init(
                            icon: "square.and.arrow.up",
                            title: AppIconDesignerLocalization.string("Xcode export"),
                            description: AppIconDesignerLocalization.string("Generate a ready-to-use AppIcon.appiconset")
                        ),
                    ],
                    tip: AppIconDesignerLocalization.string("Open App Icon Designer from the sidebar to start a new icon.")
                )
            }
        ]
    }

}
