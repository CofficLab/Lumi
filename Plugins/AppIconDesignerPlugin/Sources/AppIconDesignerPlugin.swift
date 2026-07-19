import LumiKernel
import LumiUI
import SwiftUI

public enum AppIconDesignerPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "AppIconDesigner",
        displayName: AppIconDesignerLocalization.string("App Icon Designer"),
        description: AppIconDesignerLocalization.string(
            "Design vector app icons with manual drawing tools, layer controls, and Xcode icon set export."
        ),
        order: 79,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "app.dashed",
    )

    @MainActor
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
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
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
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
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
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
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
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
