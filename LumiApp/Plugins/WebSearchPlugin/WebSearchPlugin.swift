import Foundation
import AgentToolKit
import PluginWebSearch
import os

/// Web Search 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginWebSearch.WebSearchPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor WebSearchPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-search")

    /// 日志标识符
    nonisolated static let emoji = "🔍"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true
    static let id: String = PluginWebSearch.WebSearchPlugin.id
    static let displayName: String = PluginWebSearch.WebSearchPlugin.displayName
    static let description: String = PluginWebSearch.WebSearchPlugin.description
    static let iconName: String = PluginWebSearch.WebSearchPlugin.iconName
    static var category: PluginCategory { .network }
    static var order: Int { PluginWebSearch.WebSearchPlugin.order }

    static let shared = WebSearchPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginWebSearch.WebSearchTool()]
    }
}
