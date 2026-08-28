import AppKit
import Foundation
import KernelCore
import ProviderCommand
import ProviderStorage
import KitSuperLog
import os

// MARK: - Command SuperPlugin

/// 命令插件
///
/// 提供 `CommandProviding` 服务的默认实现。
/// 负责管理所有插件的命令注册和查询。
@MainActor
public final class CommandPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.command", category: "Command")
    public let id = "com.coffic.lumi.plugin.command"
    /// Command contributions start at order 1 and above. Install the definitive
    /// provider first so early plugins do not register into the factory fallback
    /// and then lose their groups when this plugin replaces it.
    public let order = 0
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.command",
        name: "Command Super",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    public let commandService = CommandManager()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any CommandProviding).self)
        try kernel.registerProvider((any CommandProviding).self, commandService)

        // 注册内置的 Debug 命令
        commandService.registerCommandGroup(DebugCommands.makeCommandGroup(kernel: kernel))
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // Boot 阶段之后再做一次幂等注册：命令服务是所有插件共享的汇聚点，
        // Ready 时应保证宿主内置菜单仍在最终 Provider 中。
        kernel.resolveProvider((any CommandProviding).self)?
            .registerCommandGroup(DebugCommands.makeCommandGroup(kernel: kernel))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回 Debug 命令
        commandService.unregisterCommandGroup(id: DebugCommands.commandGroupID)
    }
}
