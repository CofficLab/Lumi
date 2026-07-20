import AppKit
import LumiKernel
import LumiLocalizationKit
import os
import SuperLogKit
import SwiftUI

public struct DebugCommand: Commands, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.debug")
    public nonisolated static let emoji = "🔧"
    public nonisolated static let verbose = false

    let kernel: LumiKernel

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some Commands {
        CommandMenu(String(localized: "Debug", bundle: .module)) {
            Button(String(localized: "Open App Support Directory", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Open App Support Directory")
                }
                Self.openURL(Self.appSupportDirectory())
            }

            Button(String(localized: "Open Container Directory", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Open Container Directory")
                }
                guard let directory = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
                ) else {
                    Self.showMissingDirectoryAlert(
                        title: String(localized: "Error Opening Container Directory", bundle: .module),
                        message: String(localized: "Container directory does not exist", bundle: .module)
                    )
                    return
                }

                Self.openURL(directory)
            }

            Button(String(localized: "Open Documents Directory", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Open Documents Directory")
                }
                guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    Self.showMissingDirectoryAlert(
                        title: String(localized: "Error Opening Documents Directory", bundle: .module),
                        message: String(localized: "Documents directory does not exist", bundle: .module)
                    )
                    return
                }

                Self.openURL(directory)
            }

            Divider()

            // Access data root directory from kernel's storage service.
            // DebugCommand is a SwiftUI Commands, cannot directly use @EnvironmentObject,
            // so we pass kernel via init.
            Button(String(localized: "Open Database Directory", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)Open Database Directory")
                }
                if let url = kernel.storage?.dataRootDirectory {
                    Self.openURL(url)
                } else {
                    Self.showMissingDirectoryAlert(
                        title: String(localized: "Error Opening Database Directory", bundle: .module),
                        message: String(localized: "Storage service not available", bundle: .module)
                    )
                }
            }
        }
    }

    private static func appSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    private static func openURL(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func showMissingDirectoryAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "OK", bundle: .module))
        alert.runModal()
    }
}
