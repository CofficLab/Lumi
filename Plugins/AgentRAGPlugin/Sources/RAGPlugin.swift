import AgentToolKit
import SuperLogKit
import RAGKit
import SwiftUI
import os
import LumiCoreKit
import LumiUI

/// RAG 插件
///
/// ## 架构原则
/// - RAG 服务完全由插件内部管理
/// - 内核不知道 RAG 的存在
/// - 通过中间件机制集成到消息发送流程
/// - 服务在插件启用时自动初始化
public actor RAGPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let emoji = "🦞"
    public nonisolated static let verbose: Bool = true

    public static let id = "rag"
    public static let navigationId: String = "rag_settings"
    public static let displayName = String(localized: "RAG")
    public static let description = String(localized: "Retrieval-Augmented Generation", table: "RAG")
    public static let iconName = "doc.text.magnifyingglass"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 200 }

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rag")

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = RAGPlugin()

    /// RAG 服务 - 由插件内部管理，内核不可见
    ///
    /// 在插件启用时自动初始化
    @MainActor
    private(set) static var service: RAGKit.RAGService = RAGKit.RAGService(
        databaseDirectoryProvider: {
            RAGPluginRuntime.databaseDirectoryProvider()
        },
        onProgress: { event in
            NotificationCenter.postRAGIndexProgress(event)
        }
    )

    // MARK: - Lifecycle

    public nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)RAG 插件已启用，开始初始化服务...")
        }

        // 在后台异步初始化 RAG 服务
        Task { @MainActor in
            do {
                try await Self.service.initialize()
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)RAG 服务初始化失败：\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Plugin Methods

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "RAG 代码检索",
                subtitle: "为项目建立检索索引，让助手用本地代码上下文回答问题。",
                icon: Self.iconName,
                accent: .teal,
                metrics: [
                    PluginPosterSupport.metric("Index", "索引"),
                    PluginPosterSupport.metric("Search", "检索"),
                ],
                rows: ["自动索引", "代码搜索工具", "发送上下文增强"],
                chips: ["Agent", "RAG", "代码上下文"]
            ),
            PluginPosterSupport.poster(
                title: "索引进度可见",
                subtitle: "在编辑器状态栏显示索引状态，并提供 RAG 设置入口。",
                icon: "gauge.with.dots.needle.67percent",
                accent: .cyan,
                rows: ["状态栏进度", "RAG 设置", "插件数据库"],
                chips: ["索引", "状态栏", "设置"]
            ),
        ]
    }

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        if Self.verbose {
            Self.logger.info("\(Self.t)RAG 中间件已注册")
        }
        return []
    }

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [RAGCodeSearchTool()]
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        nil
    }

    @MainActor
    public func addSettingsView() -> AnyView? {
        nil
    }

    /// 提供状态栏右侧视图（仅在编辑器激活时显示）
    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        return AnyView(RAGStatusBarView())
    }

    /// 获取 RAG 服务实例
    /// - Returns: RAGService 单例
    @MainActor
    public static func getService() -> RAGKit.RAGService {
        service
    }
}
