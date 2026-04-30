import MagicKit
import os
import SwiftUI

/// Git 提交历史插件（含详情）
///
/// 提供统一的面板视图：左侧为提交历史列表，右侧为选中 commit 的详情与 diff。
actor GitCommitHistoryPlugin: SuperPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git-commit-history")

    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = false
    static let id = "GitCommitHistory"
    static let displayName = String(localized: "Commit History", table: "GitCommitHistory")
    static let description = String(localized: "Display Git commit history and detail", table: "GitCommitHistory")
    static let iconName = "puzzlepiece"
    static var order: Int { 11 }
    static let enable: Bool = true
    static var isConfigurable: Bool { false }

    static let shared = GitCommitHistoryPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    /// 包裹 RootView，确保 commit 选择时自动激活当前面板
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(GitCommitHistoryRootOverlay(content: content()))
    }

    /// 该面板不需要右侧栏

    /// 统一面板视图：左侧历史列表 + 右侧详情
    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == "clock.badge.checkmark" else { return nil }
        return AnyView(GitCommitPanelView())
    }

    nonisolated func addPanelIcon() -> String? { "clock.badge.checkmark" }
}
