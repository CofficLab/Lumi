import AgentToolKit
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderToolManager
import SwiftUI

/// KernelCore 版本的思维导图设计器插件。
///
/// 由旧版 `Plugins/MindMapPlugin`（KernelLumi / LumiPlugin）复刻而来，
/// 形态对齐 `PluginAppStorePromoDesigner` / `PluginAppIconDesigner`：
/// SuperPlugin + SuperAgentTool + Provider 注册表。
@MainActor
public final class MindMapDesignerPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.mind-map-designer"
    public let order = 81
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.mind-map-designer",
        name: "Mind Map Designer",
        description: "",
        category: .design,
        stage: .stable,
        policy: .enabledByDefault
    )

    public static let railTabID = "mind-map.documents"

    public var name: String {
        MindMapLocalization.string("Mind Map Designer")
    }

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        MindMapDesignerRuntime.configure(kernel: kernel, pluginID: id)

        // 注册 Agent 工具到 ToolManagerProviding。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                groupID: id,
                title: MindMapLocalization.string("Mind Maps"),
                systemImage: "doc.text",
                order: order
            ) {
                MindMapRailView()
            },
        ])

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "brain.head.profile",
                    order: order,
                    ownerPluginID: id
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    MindMapStore.shared.reload()
                    contentView?.setContentView(AnyView(MindMapDesignerView()))
                    railView?.activateGroup(id: self.id)
                },
            ])
        } else {
            MindMapStore.shared.reload()
            contentView?.setContentView(AnyView(MindMapDesignerView()))
            railView?.activateGroup(id: id)
        }

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { MindMapAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { MindMapManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回注册的 Agent 工具。
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }

        kernel.resolveProvider((any RailViewProviding).self)?
            .removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        MindMapDesignerRuntime.reset()
    }

    // MARK: - Agent Tools

    /// 本插件贡献的 Agent 工具（复刻旧版 MindMapPlugin.agentTools）。
    public static let agentTools: [any SuperAgentTool] = [
        ListMindMapsTool(),
        CreateMindMapTool(),
        AddChildNodeTool(),
        UpdateNodeTool(),
        DeleteNodeTool(),
        MoveNodeTool(),
        SaveMindMapTool(),
        LoadMindMapTool(),
        ExportMindMapTool(),
        ImportOutlineTool(),
    ]
}
