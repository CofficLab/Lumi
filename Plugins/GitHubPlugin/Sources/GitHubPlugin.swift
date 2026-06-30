import GitHubKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// GitHub 插件：CLI 检测、生态洞察 + GitHub API 远程操作。
public enum GitHubPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "network"

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.github"
    )

    public static var verbose: Bool { false }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.github",
        displayName: GitHubPluginLocalization.string("GitHub"),
        description: GitHubPluginLocalization.string("GitHub CLI detection, ecosystem insight, local knowledge base, and GitHub API tools."),
        order: 16
    )

    // MARK: - Insight Features

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapIfNeeded()
        return [GitHubKBChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapIfNeeded()
        return [
            // Insight tools
            QueryEcoKBTool(),
            GitHubCLICheckTool(),
            // GitHub API tools
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

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        bootstrapIfNeeded()
        let projectPath = context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        return [
            LumiStatusBarItem(
                id: "\(info.id).kb",
                title: GitHubPluginLocalization.string("GitHub Ecosystem KB"),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    GitHubKBStatusBarView(projectPath: projectPath)
                }
            )
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        bootstrapIfNeeded()
        return AnyView(GitHubPluginSettingsView())
    }

    // MARK: - Bootstrap

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

enum GitHubPluginLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
