import AppKit
import Foundation
import LumiKernel
import SuperLogKit
import os

/// Debug 菜单命令注册
///
/// 在 OnBoot 阶段注册 Debug 菜单命令到 CommandService。
/// 这些命令允许用户快速打开各类应用目录。
@MainActor
public struct DebugCommands {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.command.debug")
    nonisolated static let verbose = false

    public init() {}

    /// 注册 Debug 菜单命令
    public func register(into kernel: LumiKernel) {
        let group = CommandMenuGroup(
            id: "com.coffic.lumi.plugin.command.debug",
            name: LumiPluginLocalization.string("Debug", bundle: .module),
            items: [
                CommandItem(
                    id: "debug.openAppSupport",
                    title: LumiPluginLocalization.string("Open App Support Directory", bundle: .module)
                ) {
                    Self.openAppSupportDirectory()
                },
                CommandItem(
                    id: "debug.openContainer",
                    title: LumiPluginLocalization.string("Open Container Directory", bundle: .module)
                ) {
                    Self.openContainerDirectory()
                },
                CommandItem(
                    id: "debug.openDocuments",
                    title: LumiPluginLocalization.string("Open Documents Directory", bundle: .module)
                ) {
                    Self.openDocumentsDirectory()
                },
                CommandItem(
                    id: "debug.openDatabase",
                    title: LumiPluginLocalization.string("Open Database Directory", bundle: .module)
                ) {
                    Self.openDatabaseDirectory(kernel: kernel)
                },
            ],
            placement: .topLevelMenu
        )

        kernel.command?.registerCommandGroup(group)

        if Self.verbose {
            Self.logger.info("Registered Debug commands")
        }
    }

    // MARK: - Actions

    private static func openAppSupportDirectory() {
        if Self.verbose {
            Self.logger.info("Open App Support Directory")
        }
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            showMissingDirectoryAlert(
                title: LumiPluginLocalization.string("Error Opening App Support Directory", bundle: .module),
                message: LumiPluginLocalization.string("App Support directory does not exist", bundle: .module)
            )
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func openContainerDirectory() {
        if Self.verbose {
            Self.logger.info("Open Container Directory")
        }
        guard let directory = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
        ) else {
            showMissingDirectoryAlert(
                title: LumiPluginLocalization.string("Error Opening Container Directory", bundle: .module),
                message: LumiPluginLocalization.string("Container directory does not exist", bundle: .module)
            )
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    private static func openDocumentsDirectory() {
        if Self.verbose {
            Self.logger.info("Open Documents Directory")
        }
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showMissingDirectoryAlert(
                title: LumiPluginLocalization.string("Error Opening Documents Directory", bundle: .module),
                message: LumiPluginLocalization.string("Documents directory does not exist", bundle: .module)
            )
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    private static func openDatabaseDirectory(kernel: LumiKernel) {
        if Self.verbose {
            Self.logger.info("Open Database Directory")
        }
        guard let url = kernel.storage?.dataRootDirectory else {
            showMissingDirectoryAlert(
                title: LumiPluginLocalization.string("Error Opening Database Directory", bundle: .module),
                message: LumiPluginLocalization.string("Storage service not available", bundle: .module)
            )
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func showMissingDirectoryAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: LumiPluginLocalization.string("OK", bundle: .module))
        alert.runModal()
    }
}
