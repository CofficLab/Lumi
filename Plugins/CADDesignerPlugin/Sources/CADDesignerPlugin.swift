import LumiCoreKit
import LumiUI
import SwiftUI

/// CAD Designer 插件：铝型材 3D 设计工具。
///
/// 参考文档 `docs/cad-designer-plugin-proposal.md`。提供 3D 视口、组件库、BOM、
/// 切割优化、项目保存/加载，以及一组 AgentTool 供 AI 用自然语言操控设计。
public enum CADDesignerPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.cad-designer",
        displayName: CADDesignerLocalization.string("CAD Designer"),
        description: CADDesignerLocalization.string(
            "Design aluminum profile frames with 3D preview, BOM, and cut optimization."
        ),
        order: 80,
        category: .general,
        policy: .optIn,
        stage: .beta,
        iconName: "cube.transparent.fill",
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                CADDesignerView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            CreateCADProjectTool(),
            PlaceProfileTool(),
            UpdateProfileTool(),
            PlaceConnectorTool(),
            ConnectComponentsTool(),
            GenerateBOMTool(),
            OptimizeCuttingTool(),
            SaveCADProjectTool(),
            LoadCADProjectTool(),
            BuildFrameTool(),
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
}
