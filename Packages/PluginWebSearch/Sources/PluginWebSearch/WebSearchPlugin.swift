import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// Web Search 插件。
///
/// 提供基础的网页搜索工具。
/// 主要用于满足阿里云 Qwen 系列模型对 Function Calling 的限制要求：
/// 当使用 web_extractor 或 web_fetch 工具时，必须同时声明 web_search 工具。
public actor WebSearchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-search")

    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "WebSearch"
    public static let displayName: String = PluginWebSearchLocalization.string("Web Search")
    public static let description: String = PluginWebSearchLocalization.string("提供网页搜索功能支持，满足 Qwen 等模型的 Function Calling 限制。")
    public static let iconName: String = "magnifyingglass"
    public static let isConfigurable: Bool = false
    public static let enable: Bool = true
    public static var category: PluginCategory { .network }
    public static var order: Int { 101 }

    public static let shared = WebSearchPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [WebSearchTool()]
    }
}

enum PluginWebSearchLocalization {
    static let table = "WebSearch"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
