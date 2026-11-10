import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderCommand
import ProviderDocsView
import ProviderStorage

// MARK: - Command SuperPlugin

/// 命令插件
///
/// 提供 `CommandProviding` 服务的默认实现。
/// 负责管理所有插件的命令注册和查询。
@MainActor
public final class CommandPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.command", category: "Command")

    public let id: String
    public let order = 0
    public let metadata: PluginMetadata

    /// 汇聚所有插件命令的服务实例。
    public let commandService = CommandManager()

    /// - Parameter bundleID: 插件唯一标识。默认使用 Lumi 系列 ID；
    ///   宿主 App 需要保留自身命名空间时（如 GitOK/Kuzee），可传入各自的应用 ID。
    public init(bundleID: String = "com.coffic.lumi.plugin.command") {
        self.id = bundleID
        self.metadata = PluginMetadata(
            id: bundleID,
            name: "Command Super",
            description: "",
            category: .core,
            stage: .stable,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any CommandProviding).self)
        try kernel.registerProvider((any CommandProviding).self, commandService)

#if os(macOS)
        // 注册内置的 Debug 命令
        commandService.registerCommandGroup(DebugCommands.makeCommandGroup(kernel: kernel, bundleID: id))
#endif
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // Boot 阶段之后再做一次幂等注册：命令服务是所有插件共享的汇聚点，
        // Ready 时应保证宿主内置菜单仍在最终 Provider 中。
#if os(macOS)
        kernel.resolveProvider((any CommandProviding).self)?
            .registerCommandGroup(DebugCommands.makeCommandGroup(kernel: kernel, bundleID: id))
#endif
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
#if os(macOS)
        // 撤回 Debug 命令
        commandService.unregisterCommandGroup(id: DebugCommands.commandGroupID(for: id))
#endif
    }

#if os(macOS)
    public func onRegister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: metadata.name) { CommandAboutView() }
        )
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
#endif
}
