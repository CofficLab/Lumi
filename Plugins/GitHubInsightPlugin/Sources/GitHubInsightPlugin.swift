import AgentToolKit
import LumiCoreKit
import LumiUI
import os
import SwiftUI

/// GitHub 生态洞察：本地知识库缓存、上下文注入与 Agent 查询工具。
public enum GitHubInsightPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .development
    public static let iconName = "network"

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.github-insight"
    )

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.github-insight",
        displayName: String(localized: "GitHub Insight", bundle: .module),
        description: String(
            localized: "Builds a local cache of GitHub ecosystem references for the current project.",
            bundle: .module
        ),
        order: 16
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        return [GitHubKBChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        bootstrapFromLumiCoreIfNeeded()
        return [QueryEcoKBTool().asLumiAgentTool()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        bootstrapFromLumiCoreIfNeeded()
        let projectPath = context.resolve(LumiCurrentProjectPathProviding.self)?.currentProjectPath ?? ""
        return [
            LumiStatusBarItem(
                id: "\(info.id).kb",
                title: String(localized: "GitHub Ecosystem KB", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    GitHubKBStatusBarView(projectPath: projectPath)
                }
            )
        ]
    }
}
