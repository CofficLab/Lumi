import MagicKit
import SwiftUI

/// RAG 插件
///
/// 提供检索增强生成 (RAG) 功能，让 AI 能够基于项目代码回答问题。
///
/// ## 功能
/// - 提供 RAG 中间件，拦截消息并检索相关文档
/// - 自动索引当前项目
///
/// ## 工作流程
/// 1. 用户发送消息
/// 2. 中间件判断是否需要 RAG
/// 3. 如果需要，调用 Context 中的 ragService 检索相关文档
/// 4. 将检索结果附加到消息上下文
actor RAGPlugin: SuperPlugin, SuperLog {
    
    // MARK: - 插件属性
    
    nonisolated static let emoji = "🦞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
    
    static let id = "rag"
    static let navigationId = "rag_settings"
    static let displayName = String(localized: "RAG", table: "RAG")
    static let description = String(localized: "Retrieval-Augmented Generation", table: "RAG")
    static let iconName = "doc.text.magnifyingglass"
    static let isConfigurable = true
    static var order: Int { 200 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = RAGPlugin()
    
    // MARK: - 状态
    
    /// 是否启用 RAG
    private var isEnabled = true
    
    /// 已索引的项目路径
    private var indexedProjects: Set<String> = []
    
    // MARK: - 初始化
    
    init() {
        AppLogger.rag.info("\(Self.t)🦞 RAG 插件已加载")
    }
    
    // MARK: - 插件协议实现
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                RAGSettingsView(plugin: self)
            }
        ]
    }
    
    // MARK: - 中间件
    
    /// 获取 RAG 中间件
    ///
    /// - Returns: RAG 发送中间件实例
    @MainActor
    func getMiddleware() -> RAGSendMiddleware {
        RAGSendMiddleware(plugin: self)
    }
    
    // MARK: - 公开方法
    
    /// 启用 RAG
    func enable() {
        isEnabled = true
        AppLogger.rag.info("\(Self.t)✅ RAG 已启用")
    }
    
    /// 禁用 RAG
    func disable() {
        isEnabled = false
        AppLogger.rag.info("\(Self.t)❌ RAG 已禁用")
    }
    
    /// 检查是否启用
    func checkEnabled() async -> Bool {
        isEnabled
    }
    
    /// 索引项目
    ///
    /// - Parameters:
    ///   - path: 项目路径
    ///   - ragService: RAG 服务
    func indexProject(at path: String, ragService: RAGService) async throws {
        guard !indexedProjects.contains(path) else {
            AppLogger.rag.info("\(Self.t)⏭️ 项目已索引：\(path)")
            return
        }
        
        try await ragService.initialize()
        try await ragService.indexProject(at: path)
        
        indexedProjects.insert(path)
        AppLogger.rag.info("\(Self.t)✅ 项目索引完成：\(path)")
    }
}

// MARK: - 预览

#Preview("设置") {
    RAGSettingsView(plugin: RAGPlugin.shared)
        .inRootView()
}
