import AgentToolKit
import GitHubKit
import LumiCoreKit
import os
import SwiftUI

/// GitHub 工具插件：提供访问 GitHub API 的 Agent 工具。
public enum GitHubToolsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "star.circle.fill"
    public static let verbose: Bool = false
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-tools")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.github-tools",
        displayName: LumiPluginLocalization.string("GitHub Tools", bundle: .module),
        description: LumiPluginLocalization.string("提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索/Issue 管理）。", bundle: .module),
        order: 15
    )

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapIfNeeded()
        return [
            GitHubRepoInfoTool().asLumiAgentTool(),
            GitHubSearchTool().asLumiAgentTool(),
            GitHubFileContentTool().asLumiAgentTool(),
            GitHubTrendingTool().asLumiAgentTool(),
            GitHubIssueListTool().asLumiAgentTool(),
            GitHubIssueDetailTool().asLumiAgentTool(),
            GitHubCreateIssueTool().asLumiAgentTool(),
            GitHubUpdateIssueTool().asLumiAgentTool(),
            GitHubCloseIssueTool().asLumiAgentTool(),
            GitHubReopenIssueTool().asLumiAgentTool(),
            GitHubIssueCommentsTool().asLumiAgentTool(),
            GitHubAddIssueCommentTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func settingsDetailView(context: LumiPluginContext) -> AnyView? {
        bootstrapIfNeeded()
        return AnyView(GitHubPluginSettingsView())
    }

    @MainActor
    private static func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        let settingsStore = GitHubPluginLocalStore()
        settingsStore.migrateLegacyValueIfMissing(forKey: "GitHubToken")
        GitHubAPIService.shared.setTokenProvider(settingsStore)
        didBootstrap = true
    }
}

private nonisolated(unsafe) var didBootstrap = false
