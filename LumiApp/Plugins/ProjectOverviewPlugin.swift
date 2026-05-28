import Foundation
import AgentToolKit
import PluginProjectOverview
import os

/// Project Overview 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginProjectOverview.ProjectOverviewPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor ProjectOverviewPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-overview")

    /// 日志标识符
    nonisolated static let emoji = "📋"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true

    static let id: String = PluginProjectOverview.ProjectOverviewPlugin.id
    static let displayName: String = PluginProjectOverview.ProjectOverviewPlugin.displayName
    static let description: String = PluginProjectOverview.ProjectOverviewPlugin.description
    static let iconName: String = PluginProjectOverview.ProjectOverviewPlugin.iconName
    static var category: PluginCategory { .general }
    static var order: Int { PluginProjectOverview.ProjectOverviewPlugin.order }

    static let shared = ProjectOverviewPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginProjectOverview.ProjectOverviewTool()]
    }
}
