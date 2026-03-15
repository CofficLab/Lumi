import Foundation
import MagicKit

/// Project Overview plugin
///
/// Provides one Agent tool that returns a short overview of a project (path, type, top-level structure, Git info, key files).
actor ProjectOverviewPlugin: SuperPlugin {
    static let id: String = "ProjectOverview"
    static let displayName: String = "Project Overview"
    static let description: String = "提供项目总览工具，返回项目类型、顶层结构、Git 信息与关键文件。"
    static let iconName: String = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 14 }

    static let shared = ProjectOverviewPlugin()

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(ProjectOverviewToolsFactory())]
    }
}

@MainActor
private struct ProjectOverviewToolsFactory: AgentToolFactory {
    let id: String = "project.overview.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [ProjectOverviewTool()]
    }
}
