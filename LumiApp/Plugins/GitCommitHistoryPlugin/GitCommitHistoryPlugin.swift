import MagicKit
import os
import SwiftUI

/// Git 提交历史插件
///
/// 在侧边栏中显示当前项目的 Git 提交历史列表，
/// 支持分页加载、下拉刷新，参考 GitOK 的 CommitList 实现。
actor GitCommitHistoryPlugin: SuperPlugin {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git-commit-history")

    nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    static let id = "GitCommitHistory"
    static let displayName = String(localized: "Commit History", table: "GitCommitHistory")
    static let description = String(localized: "Display Git commit history in sidebar", table: "GitCommitHistory")
    static let iconName = "clock.badge.checkmark"
    static var order: Int { 11 }
    static let enable: Bool = true

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { false }

    static let shared = GitCommitHistoryPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addSidebarView() -> AnyView? {
        return AnyView(GitCommitHistorySidebarView())
    }
}
