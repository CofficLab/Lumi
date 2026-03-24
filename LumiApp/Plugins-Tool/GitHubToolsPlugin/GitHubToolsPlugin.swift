import Foundation
import MagicKit
import os
import SwiftUI

/// GitHub 工具插件
///
/// 提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索）。
actor GitHubToolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-tools")
    /// 日志标识符
    nonisolated static let emoji = "🐙"

    /// 是否启用详细日志
    nonisolated static let verbose = true

    // MARK: - Plugin Properties

    static let id: String = "GitHubTools"
    static let displayName: String = String(localized: "GitHub Tools", table: "GitHubTools")
    static let description: String = String(localized: "", table: "GitHubTools")
    static let iconName: String = "star.circle.fill"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 15 }

    static let shared = GitHubToolsPlugin()

    private init() {}

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(GitHubToolsFactory())]
    }

    // MARK: - Settings View

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(GitHubPluginSettingsView())
    }
}

// MARK: - Tools Factory

@MainActor
private struct GitHubToolsFactory: AgentToolFactory {
    let id: String = "github.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            GitHubRepoInfoTool(),
            GitHubSearchTool(),
            GitHubFileContentTool(),
            GitHubTrendingTool(),
            // Issue 相关工具
            GitHubIssueListTool(),
            GitHubIssueDetailTool(),
            GitHubCreateIssueTool(),
            GitHubUpdateIssueTool(),
            GitHubCloseIssueTool(),
            GitHubReopenIssueTool(),
            GitHubIssueCommentsTool(),
            GitHubAddIssueCommentTool(),
        ]
    }
}

