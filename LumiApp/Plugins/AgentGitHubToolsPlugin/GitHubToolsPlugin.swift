import Foundation
import AgentToolKit
import GitHubKit
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
    nonisolated static let verbose: Bool = true
    // MARK: - Plugin Properties

    static let id: String = "GitHubTools"
    static let displayName: String = String(localized: "GitHub Tools", table: "GitHubTools")
    static let description: String = String(localized: "提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）。", table: "GitHubTools")
    static let iconName: String = "star.circle.fill"
    static var category: PluginCategory { .developerTool }
    static var order: Int { 15 }

    static let shared = GitHubToolsPlugin()

    private init() {
        let settingsStore = GitHubPluginLocalStore()
        settingsStore.migrateLegacyValueIfMissing(forKey: "GitHubToken")
        GitHubAPIService.shared.setTokenProvider(settingsStore)
    }

    // MARK: - Agent Tools

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "GitHub Agent 工具",
                subtitle: "让助手读取仓库、搜索代码、管理 Issue 和评论。",
                icon: Self.iconName,
                accent: .black,
                metrics: [
                    PluginPosterSupport.metric("12", "工具"),
                    PluginPosterSupport.metric("API", "GitHub"),
                ],
                rows: ["仓库信息", "代码搜索", "Issue 管理", "评论操作"],
                chips: ["GitHub", "Agent 工具", "Issue"]
            ),
        ]
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            GitHubRepoInfoTool(),
            GitHubSearchTool(),
            GitHubFileContentTool(),
            GitHubTrendingTool(),
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

    // MARK: - Settings View

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(GitHubPluginSettingsView())
    }
}
