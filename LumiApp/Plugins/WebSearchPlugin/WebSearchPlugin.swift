import Foundation
import MagicKit
import os

/// Web Search 插件
///
/// 提供基础的网页搜索工具。
/// 主要用于满足阿里云 Qwen 系列模型对 Function Calling 的限制要求：
/// 当使用 web_extractor 或 web_fetch 工具时，必须同时声明 web_search 工具。
actor WebSearchPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-search")
    
    /// 日志标识符
    nonisolated static let emoji = "🔍"
    
    /// 是否启用详细日志
    nonisolated static let verbose: Bool = false
    static let id: String = "WebSearch"
    static let displayName: String = String(localized: "Web Search", table: "WebSearch")
    static let description: String = String(localized: "提供网页搜索功能支持，满足 Qwen 等模型的 Function Calling 限制。", table: "WebSearch")
    static let iconName: String = "magnifyingglass"
    static let isConfigurable: Bool = false
    
    /// 默认启用此插件，以确保 Qwen 模型能正常调用 web_fetch
    static let enable: Bool = true
    
    static var order: Int { 101 }

    static let shared = WebSearchPlugin()

    private init() {}

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(WebSearchToolFactory())]
    }
}

// MARK: - Tool Factory

@MainActor
private struct WebSearchToolFactory: SuperAgentToolFactory {
    let id: String = "web.search.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        [WebSearchTool()]
    }
}
