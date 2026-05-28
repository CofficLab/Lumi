import Foundation
import AgentToolKit
import PluginWebFetch
import os

/// Web Fetch 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginWebFetch.WebFetchPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor WebFetchPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-fetch")

    /// 日志标识符
    nonisolated static let emoji = "🌐"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true
    static let id: String = PluginWebFetch.WebFetchPlugin.id
    static let displayName: String = PluginWebFetch.WebFetchPlugin.displayName
    static let description: String = PluginWebFetch.WebFetchPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginWebFetch.WebFetchPlugin.description(for: language)
    }
    static let iconName: String = PluginWebFetch.WebFetchPlugin.iconName
    static var category: PluginCategory { .network }
    static var order: Int { PluginWebFetch.WebFetchPlugin.order }

    static let shared = WebFetchPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginWebFetch.WebFetchTool()]
    }
}
