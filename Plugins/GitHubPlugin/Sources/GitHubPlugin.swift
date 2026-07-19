import GitHubKit
import LumiKernel
import LumiUI
import os
import SwiftUI

/// GitHub 插件：CLI 检测、生态洞察 + GitHub API 远程操作。
public enum GitHubPlugin: LumiPlugin {

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.github"
    )

    public static var verbose: Bool { false }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.github",
        displayName: GitHubPluginLocalization.string("GitHub"),
        description: GitHubPluginLocalization.string("GitHub CLI detection, ecosystem insight, local knowledge base, and GitHub API tools."),
        order: 16,
        category: .development,
        policy: .optOut,
        stage: .beta,
        iconName: "network",
    )

    // MARK: - Insight Features

    @MainActor
    public static func sendMiddlewares(context: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        bootstrapIfNeeded()
        return [GitHubKBChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
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
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        bootstrapIfNeeded()
        let projectPath = context.lumiCore?.projectComponent.currentProject?.path ?? ""
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
    public static func addSettingsTabs(context: any LumiCoreAccessing) -> [LumiSettingsTabItem] {
        bootstrapIfNeeded()
        return [
            LumiSettingsTabItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                GitHubPluginSettingsView()
            }
        ]
    }

    @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        bootstrapIfNeeded()
        return AnyView(GitHubPluginAboutView())
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
