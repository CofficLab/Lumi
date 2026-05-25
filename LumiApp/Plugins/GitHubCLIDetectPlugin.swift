import Foundation
import AgentToolKit
import PluginGitHubCLIDetect
import os

/// GitHub CLI 检测插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginGitHubCLIDetect.GitHubCLIDetectPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际工具实现来自 package。
actor GitHubCLIDetectPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-cli-detect")
    /// 日志标识符
    nonisolated static let emoji = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.emoji

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.verbose
    // MARK: - Plugin Properties

    static let id: String = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.id
    static let displayName: String = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.displayName
    static let description: String = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.description
    static let iconName: String = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.iconName
    static let isConfigurable: Bool = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.isConfigurable
    static var category: PluginCategory { .general }
    static let enable: Bool = PluginGitHubCLIDetect.GitHubCLIDetectPlugin.enable
    static var order: Int { PluginGitHubCLIDetect.GitHubCLIDetectPlugin.order }

    static let shared = GitHubCLIDetectPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginGitHubCLIDetect.GitHubCLICheckTool()]
    }
}
