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

    static func localizedMenuName(locale: Locale = .current) -> String {
        LumiPluginLocalization.string("Debug", bundle: .module, locale: locale)
    }

    static func makeCommandGroup(kernel: KernelCoreContainer) -> CommandMenuGroup {
        CommandMenuGroup(
            id: commandGroupID,
            name: localizedMenuName(),
            items: [
                CommandItem(
                    id: "debug.openAppSupport",
                    title: LumiPluginLocalization.string("Open App Support Directory", bundle: .module)
                ) {
                    openDirectory(
                        url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
                        missingMessage: LumiPluginLocalization.string("App Support directory does not exist", bundle: .module)
                    )
                },
                CommandItem(
                    id: "debug.openContainer",
                    title: LumiPluginLocalization.string("Open Container Directory", bundle: .module)
                ) {
                    let url = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
                    )
                    openDirectory(url: url, missingMessage: LumiPluginLocalization.string("Container directory does not exist", bundle: .module))
                },
                CommandItem(
                    id: "debug.openDocuments",
                    title: LumiPluginLocalization.string("Open Documents Directory", bundle: .module)
                ) {
                    openDirectory(
                        url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                        missingMessage: LumiPluginLocalization.string("Documents directory does not exist", bundle: .module)
                    )
                },
                CommandItem(
                    id: "debug.openDatabase",
                    title: LumiPluginLocalization.string("Open Database Directory", bundle: .module)
                ) {
                    let url = kernel.resolveProvider((any StorageProviding).self)?.dataRootDirectory
                    openDirectory(url: url, missingMessage: LumiPluginLocalization.string("Storage service not available", bundle: .module))
                },
            ],
            placement: .topLevelMenu
        )
    }

    private static func openDirectory(url: URL?, missingMessage: String) {
        guard let url else {
            showMissingDirectoryAlert(title: LumiPluginLocalization.string("Error Opening Directory", bundle: .module), message: missingMessage)
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
