import MagicKit
import os
import SwiftUI

/// Git Commit 详情插件
///
/// 在 Agent 模式的中间栏 Detail 区域显示当前选中 commit 的详细信息，
/// 包括提交消息、作者、时间、变更统计和文件列表。
/// 参考 GitOK 的 CommitInfoView 实现。
actor GitCommitDetailPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git-commit-detail")

    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    static let id = "GitCommitDetail"
    static let displayName = String(localized: "Commit Detail", table: "GitCommitDetail")
    static let description = String(localized: "Display selected Git commit detail", table: "GitCommitDetail")
    static let iconName = "git.commit"
    static var order: Int { 12 }
    static let enable: Bool = true

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { false }

    static let shared = GitCommitDetailPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    /// 提供 Detail 视图，显示在 Agent 模式中间栏
    @MainActor
    func addDetailView() -> AnyView? {
        return AnyView(GitCommitDetailView())
    }
}
