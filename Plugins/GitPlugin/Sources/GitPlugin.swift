import LibGit2Swift
import LumiCoreKit
import SwiftUI
import SuperLogKit
import os

/// Git plugin: panel, commit history, status bar, and agent tools.
public enum GitPlugin: LumiPlugin, SuperLog {
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git")

    public static let info = LumiPluginInfo(
        id: "GitPlugin",
        displayName: LumiPluginLocalization.string("Git", bundle: .module),
        description: String(
            localized: "Git version control panel, commit history, status bar, and agent tools.",
            bundle: .module
        ),
        order: 11,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.triangle.branch",
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    // MARK: - Lifecycle

    /// 插件层的 libgit2 初始化守卫。
    ///
    /// 真正的幂等保护在 `LibGit2.initialize()` 内部（引用计数 + 锁）；
    /// 这里再加一层只是为了避免重复日志、明确表达"我们已经初始化过了"。
    /// `nonisolated(unsafe)` 安全：写入只发生在 MainActor 上下文（lifecycle 与 bootstrap），
    /// 读取也仅在 MainActor 上进行，无数据竞争。
    nonisolated(unsafe) private static var didInitializeLibGit2: Bool = false

    /// 真正的初始化逻辑：调 `LibGit2.initialize()`（幂等）并打日志。
    /// 多个入口（lifecycle / bootstrap）都路由到这一个函数。
    private static func ensureLibGit2Initialized() {
        guard !didInitializeLibGit2 else { return }
        didInitializeLibGit2 = true
        LibGit2.initialize()
    }

    /// 响应宿主生命周期事件。
    ///
    /// 关键修复：历史上 `bootstrap(chatServiceProvider:)` 是入口，但宿主从未调用它
    /// ——`LumiPluginRegistry.registerAll()` 走的是 `lifecycle(.didRegister)`，而
    /// 本插件没有实现 `lifecycle`，于是协议默认空实现吞掉了，libgit2 永远没初始化，
    /// 所有 agent 工具调 `git_repository_open_ext` 都拿到 "library has not been initialized"。
    ///
    /// 现在在 `.didRegister` 触发初始化，agent 工具运行时一定已经可用。
    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) throws {
        switch event {
        case .didRegister, .appDidLaunch:
            // .didRegister 是最早的事件，理论上足够；这里再覆盖 .appDidLaunch
            // 是防御性兜底——若宿主将来调整生命周期顺序，初始化仍然不会落下。
            ensureLibGit2Initialized()
        case .willDisable:
            break
        }
    }

    /// 历史入口：早期调用方可能直接传 `chatServiceProvider` 进来。
    /// 保留这个 API（@MainActor public static）以免破坏外部调用；现在它只是
    /// `lifecycle(.didRegister)` 的同义词，再多存一个 chatServiceProvider 引用。
    @MainActor
    public static func bootstrap(
        chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?
    ) {
        ensureLibGit2Initialized()
        GitRuntimeBridge.chatServiceProvider = chatServiceProvider
    }

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
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
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        // 不再依赖注入，直接从 LumiCore 获取项目路径
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                GitPanelHostView(lumiCore: lumiCore)
            }
        ]
    }

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        guard context.activeSectionID == info.id else { return [] }
        guard let lumiCore = context.lumiCore else { return [] }

        return [
            LumiStatusBarItem(
                id: "\(info.id).branch",
                title: "Git Branch",
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    GitPluginStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

    @MainActor
    public static func rootOverlays(context: any LumiCoreAccessing) -> [LumiRootOverlayItem] {
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiRootOverlayItem(id: "\(info.id).commit-history", order: info.order) { content in
                GitPanelRootOverlay(lumiCore: lumiCore, content: content)
            }
        ]
    }
}
