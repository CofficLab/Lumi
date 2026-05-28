import Foundation
import AgentToolKit
import PluginBrowserAgent
import os

/// Browser Agent 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginBrowserAgent.BrowserAgentPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor BrowserAgentPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent")

    /// 日志标识符
    nonisolated static let emoji = "🌐"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true

    static let id: String = PluginBrowserAgent.BrowserAgentPlugin.id
    static let displayName: String = PluginBrowserAgent.BrowserAgentPlugin.displayName
    static let description: String = PluginBrowserAgent.BrowserAgentPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginBrowserAgent.BrowserAgentPlugin.description(for: language)
    }
    static let iconName: String = PluginBrowserAgent.BrowserAgentPlugin.iconName
    static var category: PluginCategory { .general }
    static var order: Int { PluginBrowserAgent.BrowserAgentPlugin.order }

    static let shared = BrowserAgentPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginBrowserAgent.BrowserAgentTool()]
    }
}
