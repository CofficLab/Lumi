import SwiftUI
import LumiChatKit
import LumiCoreKit
import SuperLogKit
import os

/// RAG 插件：检索增强生成。
public enum RAGPlugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "doc.text.magnifyingglass"
    public nonisolated static let emoji = "🔎"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag")
    public nonisolated static let verbose = true

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.rag",
        displayName: LumiPluginLocalization.string("RAG", bundle: .module),
        description: LumiPluginLocalization.string("Retrieval-Augmented Generation", bundle: .module),
        order: 200
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

        return [
            LumiStatusBarItem(
                id: "\(info.id).status",
                title: LumiPluginLocalization.string("RAG", bundle: .module),
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
        return [RAGCodeSearchTool()]
    }
}
