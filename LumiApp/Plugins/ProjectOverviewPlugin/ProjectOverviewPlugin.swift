import Foundation
import MagicKit
import os

/// Project Overview plugin
///
/// Provides one Agent tool that returns a short overview of a project (path, type, top-level structure, Git info, key files).
actor ProjectOverviewPlugin: SuperPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-overview")
    static let id: String = "ProjectOverview"
    static let displayName: String = String(localized: "Project Overview", table: "ProjectOverview")
    static let description: String = String(localized: "提供项目总览工具，返回项目类型、顶层结构、Git 信息与关键文件。", table: "ProjectOverview")
    static let iconName: String = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 14 }

    static let shared = ProjectOverviewPlugin()

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(ProjectOverviewToolsFactory())]
    }
}

@MainActor
private struct ProjectOverviewToolsFactory: SuperAgentToolFactory {
    let id: String = "project.overview.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        [ProjectOverviewTool()]
    }
}
