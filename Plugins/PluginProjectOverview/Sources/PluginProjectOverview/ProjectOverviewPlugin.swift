import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 项目概览插件。
///
/// 提供 Agent 工具，返回项目类型、顶层结构、Git 信息、清单文件、README 预览和关键文件。
public actor ProjectOverviewPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-overview")

    public nonisolated static let emoji = "📋"
    public nonisolated(unsafe) static var verbose: Bool = false

    public static let id: String = "ProjectOverview"
    public static let displayName: String = PluginProjectOverviewLocalization.string("Project Overview")
    public static let description: String = PluginProjectOverviewLocalization.string("Provides project overview tool, returning project type, top-level structure, Git information, and key files.")

    public static func description(for language: LanguagePreference) -> String {
        PluginProjectOverviewLocalization.string("Provides project overview tool, returning project type, top-level structure, Git information, and key files.", for: language)
    }
    public static let iconName: String = "doc.text.magnifyingglass"
    public static var category: PluginCategory { .general }
    public static var order: Int { 14 }

    public static let shared = ProjectOverviewPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [ProjectOverviewTool()]
    }
}
