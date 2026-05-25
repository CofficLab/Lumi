import SwiftUI
import Foundation
import AgentToolKit
import LumiCoreKit
import os

/// Git 插件：统一提供 Git 面板、提交历史、分支状态栏、快捷提交和 Agent 工具
actor GitPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git")
    nonisolated static let emoji = "🌿"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "GitPlugin"
    static let navigationId: String? = nil
    static let displayName: String = "Git"
    static let description: String = String(localized: "提供 Git 版本控制相关的功能，包括面板、提交历史、状态栏和 Agent 工具。", table: "GitPlugin")
    static let iconName: String = "arrow.triangle.branch"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .developerTool }
    static var order: Int { 11 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = GitPlugin()

    private init() {}

    // MARK: - Agent Tools

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
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(GitCommitPanelView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }

    /// 底部状态栏 Git 入口：当前分支 + 快捷 Git 弹窗
    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(GitPluginStatusBarView())
    }
}
