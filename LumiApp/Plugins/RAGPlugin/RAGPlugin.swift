import MagicKit
import SwiftUI
import os

/// RAG 插件
///
/// ## 架构原则
/// - RAG 服务完全由插件内部管理
/// - 内核不知道 RAG 的存在
/// - 通过中间件机制集成到消息发送流程
/// - 服务在插件启用时自动初始化
actor RAGPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🦞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id = "rag"
    static let navigationId: String = "rag_settings"
    static let displayName = String(localized: "RAG")
    static let description = String(localized: "Retrieval-Augmented Generation", table: "RAG")
    static let iconName = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = false
    static var order: Int { 200 }

    static let logger = Logger(subsystem: "com.coffic.lumi", category: "RAG")

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RAGPlugin()

    /// RAG 服务 - 由插件内部管理，内核不可见
    ///
    /// 在插件启用时自动初始化
    @MainActor
    private(set) static var service: RAGService = RAGService()

    // MARK: - Lifecycle

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)🦞 RAG 插件已启用，开始初始化服务...")
        }

        // 在后台异步初始化 RAG 服务
        Task { @MainActor in
            do {
                let start = CFAbsoluteTimeGetCurrent()
                try await Self.service.initialize()
                let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
                if Self.verbose {
                    Self.logger.info("\(Self.t)✅ RAG 服务初始化完成 (\(String(format: "%.2f", duration))ms)")
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)❌ RAG 服务初始化失败：\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Plugin Methods

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        if Self.verbose {
            Self.logger.info("\(Self.t)🦞 RAG 中间件已注册")
        }
        return [AnySendMiddleware(RAGSendMiddleware())]
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RAGAutoIndexOverlay(content: content()))
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(RAGSettingsView())
    }

    /// 提供状态栏右侧视图
    @MainActor
    func addStatusBarTrailingView() -> AnyView? {
        AnyView(RAGStatusBarView())
    }

    /// 获取 RAG 服务实例
    /// - Returns: RAGService 单例
    @MainActor
    static func getService() -> RAGService {
        service
    }
}
