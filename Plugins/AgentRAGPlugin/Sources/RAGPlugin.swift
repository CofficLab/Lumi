import AgentToolKit
import LumiChatKit
import LumiCoreKit

/// RAG 插件：检索增强生成。
public enum RAGPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "doc.text.magnifyingglass"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rag",
        displayName: String(localized: "RAG", bundle: .module),
        description: String(localized: "Retrieval-Augmented Generation", bundle: .module),
        order: 200
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        RAGPluginService.initializeIfNeeded()
        return [RAGChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == ChatPanelSection.id else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).status",
                title: String(localized: "RAG", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    RAGStatusBarView()
                }
            )
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        RAGPluginService.initializeIfNeeded()
        return [RAGCodeSearchLumiTool()]
    }
}
