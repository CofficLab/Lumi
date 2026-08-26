import AppKit
import Foundation
import KernelCore
import ProviderCommand
import ProviderStorage

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
