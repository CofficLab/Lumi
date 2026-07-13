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

                // 使用 AppConfig.getDBFolderURL() 而非 LumiCore.dataRootDirectory：
                // DebugCommand 是 SwiftUI Commands,无法直接拿到 @EnvironmentObject,
                // 而 AppConfig 在 App 启动期就已配置好,等价于 LumiCore 的数据根目录。
                Button("打开数据库目录") {
                    if Self.verbose {
                        Self.logger.info("\(Self.t)打开数据库目录")
                    }
                    Self.openURL(AppConfig.getDBFolderURL())
                }
            }
        #endif
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
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
