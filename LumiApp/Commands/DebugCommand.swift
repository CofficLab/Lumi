import AppKit
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

struct DebugCommand: Commands, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.debug")
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    var body: some Commands {
        #if os(macOS)
            CommandMenu("调试") {
                Button("打开 App Support 目录") {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)打开 App Support 目录")
                    }
                    Self.openURL(Self.appSupportDirectory())
                }

                Button("打开容器目录") {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)打开容器目录")
                    }
                    guard let directory = FileManager.default.containerURL(
                        forSecurityApplicationGroupIdentifier: Bundle.main.bundleIdentifier ?? ""
                    ) else {
                        Self.showMissingDirectoryAlert(title: "打开容器目录出错", message: "容器目录不存在")
                        return
                    }

                    Self.openURL(directory)
                }

                Button("打开文档目录") {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)打开文档目录")
                    }
                    guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        Self.showMissingDirectoryAlert(title: "打开文档目录出错", message: "文档目录不存在")
                        return
                    }

                    Self.openURL(directory)
                }

                Divider()

                Button("打开数据库目录") {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)打开数据库目录")
                    }
                    Self.openURL(LumiCore.dataRootDirectory)
                }
            }
        #endif
    }

    private static func appSupportDirectory() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to resolve Application Support directory.")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let directory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private static func showMissingDirectoryAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
