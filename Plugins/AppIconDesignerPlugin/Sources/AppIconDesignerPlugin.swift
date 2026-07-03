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

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
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
            )
        ]
    }

}
