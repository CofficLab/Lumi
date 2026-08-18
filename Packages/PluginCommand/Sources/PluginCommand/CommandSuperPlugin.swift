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

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Command",
            description: "管理所有插件的命令菜单注册、分组和查询",
            category: .core,
            stage: .stable,
            policy: .alwaysOn
        )
    }

    public let commandService = CommandManager()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any CommandProviding).self)
        try kernel.registerProvider((any CommandProviding).self, commandService)

        // 注册内置的 Debug 命令
        let debugCommands = DebugCommands.makeCommands(kernel: kernel)
        for command in debugCommands {
            commandService.register(command)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 撤回 Debug 命令
        for command in DebugCommands.commandIDs {
            commandService.unregister(id: command)
        }
    }
}

// MARK: - CommandManager

/// `CommandProviding` 的默认实现。
///
/// 管理命令的注册、注销和查询。
@MainActor
public final class CommandManager: CommandProviding {
    @Published public private(set) var allCommands: [CommandItem] = []

    public init() {}

    public func register(_ command: CommandItem) {
        allCommands.removeAll { $0.id == command.id }
        allCommands.append(command)
    }

    public func unregister(id: String) {
        allCommands.removeAll { $0.id == id }
    }
}

// MARK: - Debug Commands

/// Debug 菜单命令贡献
///
/// 允许用户快速打开各类应用目录。
enum DebugCommands {
    static let commandIDs = [
        "debug.openAppSupport",
        "debug.openContainer",
        "debug.openDocuments",
        "debug.openDatabase",
    ]

    static func makeCommands(kernel: KernelCoreContainer) -> [CommandItem] {
        [
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
        ]
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
