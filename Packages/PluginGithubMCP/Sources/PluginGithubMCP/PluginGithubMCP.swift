import Foundation
import KernelCore
import KitMCP
import ProviderMCP
import KitSuperLog
import os

/// PluginGithubMCP：贡献 GitHub 官方 MCP 服务器模板。
///
/// 不自带设置 UI，不管理连接——只负责在启动时把
/// GitHub 官方 `github/github-mcp-server`（docker stdio）的服务器配置
/// 贡献给 PluginMCP 的收集器。用户在 PluginMCP 设置里启用并填写
/// `GITHUB_PERSONAL_ACCESS_TOKEN` 后，由 PluginMCP 负责连接和工具桥接。
@MainActor
public final class PluginGithubMCP: SuperPlugin, SuperLog {
    nonisolated public static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.github-mcp",
        category: "GithubMCP"
    )

    public let id = "com.coffic.lumi.plugin.github-mcp"
    public let order = 281
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.github-mcp",
        name: "GitHub MCP",
        description: "Contributes the GitHub official MCP server (docker, github-mcp-server).",
        category: .integration,
        stage: .preview,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // PluginMCP (order 270) 先 boot 并注册贡献收集器，这里再 resolve 并贡献。
        kernel.resolveProvider((any MCPServerContributionProviding).self)?.contribute(
            MCPServerTemplate.github
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {}
}
