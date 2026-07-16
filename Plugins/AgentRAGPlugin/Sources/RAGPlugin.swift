import SwiftUI
import LumiChatKit
import LumiCoreKit
import SuperLogKit
import os

/// RAG 插件：检索增强生成。
public enum RAGPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🔎"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag")
    public nonisolated static let verbose = false

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rag",
        displayName: LumiPluginLocalization.string("RAG", bundle: .module),
        description: LumiPluginLocalization.string("Retrieval-Augmented Generation", bundle: .module),
        order: 200,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "doc.text.magnifyingglass",
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        RAGPluginService.initializeIfNeeded()
        return [RAGChatMiddleware()]
    }

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: "\(info.id).index-maintenance") { content in
                ZStack {
                    content
                    RAGIndexMaintenanceView()
                }
            }
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.isChatSectionVisible else {
            return []
        }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiStatusBarItem(
                id: "\(info.id).status",
                title: LumiPluginLocalization.string("RAG", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    RAGStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        RAGPluginService.initializeIfNeeded()
        return [RAGCodeSearchTool()]
    }
}
