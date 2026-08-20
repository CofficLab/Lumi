import AppKit
import Foundation
import KernelCore
import ProviderCommand
import ProviderStorage

// MARK: - Command SuperPlugin

/// 命令插件
///
/// 提供 `CommandProviding` 服务的默认实现。
/// 负责管理所有插件的命令注册和查询。
@MainActor
public final class CommandSuperPlugin: SuperPlugin {
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

// MARK: - CommandManager

/// `CommandProviding` 的默认实现。
///
/// 管理命令的注册、注销和查询。
@MainActor
public final class CommandManager: CommandProviding {
    @Published public private(set) var allCommandGroups: [CommandMenuGroup] = []

    public init() {}

    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if let index = allCommandGroups.firstIndex(where: { $0.id == group.id }) {
            allCommandGroups[index] = group
        } else {
            allCommandGroups.append(group)
        }
    }

    public func unregisterCommandGroup(id: String) {
        allCommandGroups.removeAll { $0.id == id }
    }
}

// MARK: - Debug Commands

/// Debug 菜单命令贡献
///
/// 允许用户快速打开各类应用目录。
@MainActor
enum DebugCommands {
    static let commandGroupID = "com.coffic.lumi.plugin.command.debug"

    static func makeCommandGroup(kernel: KernelCoreContainer) -> CommandMenuGroup {
        CommandMenuGroup(
            id: commandGroupID,
            name: "DEBUG",
            items: [
                CommandItem(
                    id: "debug.openAppSupport",
                    title: "Open App Support Directory"
                ) {
                    openDirectory(
                        url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                        missingMessage: "App Support directory does not exist"
                    )
                },
                CommandItem(
                    id: "debug.openContainer",
                    title: "Open Container Directory"
                ) {
                    let url = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
                    )
                    openDirectory(url: url, missingMessage: "Container directory does not exist")
                },
                CommandItem(
                    id: "debug.openDocuments",
                    title: "Open Documents Directory"
                ) {
                    openDirectory(
                        url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                        missingMessage: "Documents directory does not exist"
                    )
                },
                CommandItem(
                    id: "debug.openDatabase",
                    title: "Open Database Directory"
                ) {
                    let url = kernel.resolveProvider((any StorageProviding).self)?.dataRootDirectory
                    openDirectory(url: url, missingMessage: "Storage service not available")
                },
            ],
            placement: .topLevelMenu
        )
    }

    private static func openDirectory(url: URL?, missingMessage: String) {
        guard let url else {
            showMissingDirectoryAlert(title: "Error Opening Directory", message: missingMessage)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func showMissingDirectoryAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
