import Foundation
import MagicKit
import os

/// GitHub CLI 检测插件
///
/// 提供一个工具用于检测用户系统是否安装了 GitHub CLI (gh) 命令行工具
actor GitHubCLIDetectPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-cli-detect")
    /// 日志标识符
    nonisolated static let emoji = "🐚"

    /// 是否启用详细日志
    nonisolated static let verbose = true

    // MARK: - Plugin Properties

    static let id: String = "GitHubCLIDetect"
    static let displayName: String = "GitHub CLI Detect"
    static let description: String = "检测系统是否安装了 GitHub CLI (gh) 命令行工具。"
    static let iconName: String = "terminal"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 16 }

    static let shared = GitHubCLIDetectPlugin()

    private init() {}

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(CLIDetectToolsFactory())]
    }
}

// MARK: - Tools Factory

@MainActor
private struct CLIDetectToolsFactory: AgentToolFactory {
    let id: String = "github.cli.detect.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [GitHubCLICheckTool()]
    }
}
