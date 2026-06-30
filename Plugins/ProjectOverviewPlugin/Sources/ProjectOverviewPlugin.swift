import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 项目概览插件。
///
/// 提供 Agent 工具，返回项目类型、顶层结构、Git 信息、清单文件、README 预览和关键文件。
public enum ProjectOverviewPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "doc.text.magnifyingglass"
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-overview")

    public static let info = LumiPluginInfo(
        id: "ProjectOverview",
        displayName: PluginProjectOverviewLocalization.string("Project Overview"),
        description: PluginProjectOverviewLocalization.string("Provides project overview tool, returning project type, top-level structure, Git information, and key files."),
        order: 14
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }
    public static var isConfigurable: Bool { policy.isConfigurable }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [ProjectOverviewTool()]
    }
}
