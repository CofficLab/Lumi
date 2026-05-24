import Foundation
import AgentToolKit
import os
import SwiftUI

/// 向 Lumi 插件系统注册 GitHub 生态洞察能力。
///
/// 插件提供状态栏视图、用于注入缓存生态参考的发送中间件，以及查询本地
/// GitHub 生态知识库的 Agent 工具。
actor GitHubInsightPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-insight")
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true

    static let id = "GitHubInsight"
    static let displayName = String(localized: "GitHub Insight", table: "GitHubInsight")
    static let description = String(localized: "Builds a local cache of GitHub ecosystem references for the current project.", table: "GitHubInsight")
    static let iconName = "network"
    static let isConfigurable = true
    static var category: PluginCategory { .developerTool }
    static let enable = true
    static var order: Int { 16 }
    static let shared = GitHubInsightPlugin()

    private init() {}

    /// 在状态栏右侧添加 GitHub 生态知识库状态指示器。
    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(GitHubKBStatusBarView())
    }

    /// 注册可用缓存 GitHub 上下文增强外发消息的发送中间件。
    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(GitHubKBMiddleware())]
    }

    /// 注册此插件暴露给 Agent 的工具。
    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [QueryEcoKBTool()]
    }
}
