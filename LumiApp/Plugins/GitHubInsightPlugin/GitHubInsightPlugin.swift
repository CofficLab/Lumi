import Foundation
import AgentToolKit
import LumiCoreKit
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
    static var category: PluginCategory { .developerTool }
    static var order: Int { 16 }
    static let policy: PluginPolicy = .optOut
    static let shared = GitHubInsightPlugin()

    private init() {}

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "GitHub 生态知识库",
                subtitle: "为当前项目缓存 GitHub 生态参考，并在对话中注入可检索上下文。",
                icon: Self.iconName,
                accent: .blue,
                metrics: [
                    PluginPosterSupport.metric("KB", "本地缓存"),
                    PluginPosterSupport.metric("Query", "检索"),
                ],
                rows: ["生态参考同步", "状态栏指示", "Agent 查询工具"],
                chips: ["GitHub", "知识库", "上下文"]
            ),
        ]
    }

    /// 在状态栏右侧添加 GitHub 生态知识库状态指示器。
    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
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
