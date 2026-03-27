import MagicKit
import SwiftUI
import os

/// RAG 插件
///
/// ## 架构原则
/// - RAG 服务完全由插件内部管理
/// - 内核不知道 RAG 的存在
/// - 通过中间件机制集成到消息发送流程
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
    /// 使用 lazy 确保首次使用时才初始化
    @MainActor
    private(set) static var service: RAGService = RAGService()

    @MainActor
    func sendMiddlewares() -> [AnySendMiddleware] {
        if Self.verbose {
            Self.logger.info("\(Self.t)🦞 RAG 中间件已启用")
        }
        return [AnySendMiddleware(RAGSendMiddleware())]
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(RAGSettingsView())
    }

    /// 提供状态栏视图
    @MainActor
    func addStatusBarView() -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(Self.t)🦞 RAG 状态栏视图已启用")
        }
        return AnyView(RAGStatusBarView())
    }

    /// 获取 RAG 服务实例
    /// - Returns: RAGService 单例
    @MainActor
    static func getService() -> RAGService {
        service
    }
}
