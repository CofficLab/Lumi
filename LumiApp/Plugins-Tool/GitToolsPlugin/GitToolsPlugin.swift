import Foundation
import MagicKit
import SwiftUI
import os

/// Git 工具插件
///
/// 提供 Git 版本控制相关的 Agent 工具（状态/差异/日志）。
actor GitToolsPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git-tools")

    /// 日志标识符
    nonisolated static let emoji = "📦"

    /// 是否启用详细日志
    nonisolated static let verbose = true

    // MARK: - Plugin Properties

    static let id: String = "GitTools"
    static let displayName: String = String(localized: "Git Tools", table: "GitTools")
    static let description: String = String(localized: "", table: "GitTools")
    static let iconName: String = "git"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 16 }

    static let shared = GitToolsPlugin()

    private init() {}

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(GitToolsFactory())]
    }
}

// MARK: - Tools Factory

@MainActor
private struct GitToolsFactory: AgentToolFactory {
    let id: String = "git.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            GitStatusTool(),
            GitDiffTool(),
            GitLogTool(),
        ]
    }
}
