import SwiftUI
import Foundation
import AgentToolKit
import LumiCoreKit
import os

/// Git 插件：统一提供 Git 面板、提交历史、分支状态栏、快捷提交和 Agent 工具
actor GitPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git")
    nonisolated static let emoji = "🌿"
    nonisolated static let verbose: Bool = true

    static let id: String = "GitPlugin"
    static let navigationId: String? = nil
    static let displayName: String = "Git"
    static let description: String = String(localized: "提供 Git 版本控制相关的功能，包括面板、提交历史、状态栏和 Agent 工具。", table: "GitPlugin")
    static let iconName: String = "arrow.triangle.branch"
    static var category: PluginCategory { .developerTool }
    static var order: Int { 11 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }
    static let shared = GitPlugin()

    private init() {}

    // MARK: - Agent Tools

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "Git 变更面板",
                subtitle: "查看提交历史、当前 diff、分支状态，并提供 Agent 工具。",
                icon: Self.iconName,
                accent: .green,
                metrics: [
                    PluginPosterSupport.metric("Diff", "变更"),
                    PluginPosterSupport.metric("Log", "历史"),
                ],
                rows: ["工作区 Diff", "提交历史", "分支状态栏"],
                chips: ["开发工具", "Git", "Agent 工具"]
            ),
            PluginPosterSupport.poster(
                title: "Agent 可调用 Git 工具",
                subtitle: "让助手读取状态、查看 diff、创建 commit、检查未推送提交。",
                icon: "wand.and.stars",
                accent: .teal,
                rows: ["git status", "git diff", "git commit", "git unpushed"],
                chips: ["工具调用", "版本控制", "自动化"]
            ),
        ]
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            GitStatusTool(),
            GitDiffTool(),
            GitLogTool(),
            GitCommitTool(),
            GitShowTool(),
            GitBranchTool(),
            GitUnpushedTool(),
        ]
    }

    @MainActor
    func subAgentDefinitions() -> [any SubAgentDefinitionProtocol] {
        [
            GitCommitSubAgentDefinition(),
        ]
    }

    // MARK: - UI Contributions

    /// 包裹 RootView，确保 commit 选择时自动激活 Git 面板
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(GitCommitHistoryRootOverlay(content: content()))
    }

    /// 左侧活动栏 Git 面板：提交历史 + commit 详情 + 工作区 diff
    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName, showsProjectToolbar: true) {
            AnyView(GitCommitPanelView())
        }
    }

    /// 底部状态栏 Git 入口：当前分支 + 快捷 Git 弹窗
    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(GitPluginStatusBarView())
    }
}
