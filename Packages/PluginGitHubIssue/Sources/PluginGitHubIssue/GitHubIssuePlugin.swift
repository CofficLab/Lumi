import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderToolManager

/// GitHub Issue 插件：把 Agent 工具故障提交成 GitHub issue。
///
/// 设计：
/// - 不直接调 GitHub REST API、不管理 token——所有认证与仓库定位由本地 `gh` CLI 完成。
/// - `onBoot` 向 `ToolManagerProviding` 注册 `github_create_issue`；`onShutdown` 撤回。
/// - `policy = .enabledByDefault`：默认开启，但工具在 gh 不可用时优雅返回错误文本，
///   LLM 可据此放弃提交。
@MainActor
public final class GitHubIssuePlugin: SuperPlugin, SuperLog {
    nonisolated public static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.github-issue",
        category: "GitHubIssue"
    )
    public nonisolated static let emoji = "🐙"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.github-issue"
    public let order = 290
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.github-issue",
        name: "GitHub Issue",
        description: "Submit tool bugs as GitHub issues via the local `gh` CLI.",
        category: .integration,
        stage: .preview,
        policy: .enabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding; GitHub issue tool was not registered")
            return
        }
        toolManager.add(CreateGitHubIssueTool(), pluginID: id)
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered \(CreateGitHubIssueTool.toolName)")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: CreateGitHubIssueTool.toolName)
    }
}
