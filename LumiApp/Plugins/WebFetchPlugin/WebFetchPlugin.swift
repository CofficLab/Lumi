import Foundation
import MagicKit
import os

/// Web Fetch 插件
///
/// 提供网页抓取和内容提取功能。
/// 支持将 HTML 转换为 Markdown 格式，便于 AI 理解和处理。
actor WebFetchPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-fetch")
    
    /// 日志标识符
    nonisolated static let emoji = "🌐"
    
    /// 是否启用详细日志
    nonisolated static let verbose: Bool = false
    static let id: String = "WebFetch"
    static let displayName: String = String(localized: "Web Fetch", table: "WebFetch")
    static let description: String = String(localized: "提供网页抓取和内容提取功能，支持 HTML 转 Markdown。", table: "WebFetch")
    static let iconName: String = "globe"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 100 }

    static let shared = WebFetchPlugin()

    private init() {}

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(WebFetchToolFactory())]
    }
}

// MARK: - Tool Factory

@MainActor
private struct WebFetchToolFactory: SuperAgentToolFactory {
    let id: String = "web.fetch.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [AgentTool] {
        [WebFetchTool()]
    }
}