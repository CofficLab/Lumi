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
            name: "Debug",
            items: [
                CommandItem(
                    id: "debug.openAppSupport",
                    title: String(localized: "Open App Support Directory")
                ) {
                    Self.openAppSupportDirectory()
                },
                CommandItem(
                    id: "debug.openContainer",
                    title: String(localized: "Open Container Directory")
                ) {
                    Self.openContainerDirectory()
                },
                CommandItem(
                    id: "debug.openDocuments",
                    title: String(localized: "Open Documents Directory")
                ) {
                    Self.openDocumentsDirectory()
                },
                CommandItem(
                    id: "debug.openDatabase",
                    title: String(localized: "Open Database Directory")
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
                title: String(localized: "Error Opening App Support Directory"),
                message: String(localized: "App Support directory does not exist")
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
                title: String(localized: "Error Opening Container Directory"),
                message: String(localized: "Container directory does not exist")
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
                title: String(localized: "Error Opening Documents Directory"),
                message: String(localized: "Documents directory does not exist")
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
                title: String(localized: "Error Opening Database Directory"),
                message: String(localized: "Storage service not available")
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
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
