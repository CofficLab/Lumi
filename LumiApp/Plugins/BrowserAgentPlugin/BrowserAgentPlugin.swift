import Foundation
import AgentToolKit
import os

/// Browser Agent 插件
///
/// 提供浏览器自动化功能，基于 agent-browser CLI 工具。
/// 支持网页导航、元素交互、截图、快照等浏览器操作。
actor BrowserAgentPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent")

    /// 日志标识符
    nonisolated static let emoji = "🌐"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true

    static let id: String = "BrowserAgent"
    static let displayName: String = String(localized: "Browser Agent", table: "BrowserAgent")
    static let description: String = String(localized: "Browser automation powered by agent-browser CLI", table: "BrowserAgent")
    static let iconName: String = "globe"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .general }
    static let enable: Bool = true
    static var order: Int { 103 }

    static let shared = BrowserAgentPlugin()

    private init() {}

    func onEnable() async {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [BrowserAgentTool()]
    }
}
