import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import GitHubKit
import LumiUI
import os
import SwiftUI

/// GitHub 工具插件
///
/// 提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索）。
public actor GitHubToolsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-tools")
    /// 日志标识符
    public nonisolated static let emoji = "🐙"

    /// 是否启用详细日志
    public nonisolated static let verbose: Bool = true
    // MARK: - Plugin Properties

    public static let id: String = "GitHubTools"
    public static let displayName: String = String(localized: "GitHub Tools", bundle: .module)
    public static let description: String = String(localized: "提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）。", bundle: .module)
    public static let iconName: String = "star.circle.fill"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 15 }

    public static let shared = GitHubToolsPlugin()

    private init() {
        let settingsStore = GitHubPluginLocalStore()
        settingsStore.migrateLegacyValueIfMissing(forKey: "GitHubToken")
        GitHubAPIService.shared.setTokenProvider(settingsStore)
    }

    // MARK: - Agent Tools

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "GitHub Agent 工具",
                subtitle: "让助手读取仓库、搜索代码、管理 Issue 和评论。",
                icon: Self.iconName,
                accent: Color.black,
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
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
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
    public func addSettingsView() -> AnyView? {
        AnyView(GitHubPluginSettingsView())
    }
}
