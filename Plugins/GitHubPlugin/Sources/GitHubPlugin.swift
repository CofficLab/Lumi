import AgentToolKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// GitHub 插件：合并了 CLI 检测和生态洞察功能。
public enum GitHubPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "network"

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.github"
    )

    public static var verbose: Bool { false }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.github",
        displayName: PluginGitHubLocalization.string("GitHub"),
        description: PluginGitHubLocalization.string("GitHub CLI detection, ecosystem insight and local knowledge base."),
        order: 16
    )

    // MARK: - Insight Features

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        return [GitHubKBChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapFromLumiCoreIfNeeded()
        return [
            QueryEcoKBTool().asLumiAgentTool(),
            GitHubCLICheckTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        bootstrapFromLumiCoreIfNeeded()
        let projectPath = context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        return [
            LumiStatusBarItem(
                id: "\(info.id).kb",
                title: PluginGitHubLocalization.string("GitHub Ecosystem KB"),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    GitHubKBStatusBarView(projectPath: projectPath)
                }
            )
        ]
    }
}

enum PluginGitHubLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
