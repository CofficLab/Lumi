import MagicKit
import SwiftUI
import Foundation
import os

/// Git 分支状态栏插件：在 Agent 模式底部状态栏显示当前项目所属的 Git 分支
actor GitBranchStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git-branch-status-bar")
    nonisolated static let emoji = "🌿"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "GitBranchStatusBar"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Git Branch Status", table: "GitBranchStatusBar")
    static let description: String = String(localized: "Display current git branch in status bar", table: "GitBranchStatusBar")
    static let iconName: String = "arrow.triangle.branch"
    static let isConfigurable: Bool = false
    static var order: Int { 94 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = GitBranchStatusBarPlugin()

    // MARK: - UI Contributions

    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        return AnyView(GitBranchStatusBarView())
    }
}
