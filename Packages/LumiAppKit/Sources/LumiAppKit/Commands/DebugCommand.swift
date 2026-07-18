import LumiLocalizationKit
import AppKit
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

public struct DebugCommand: Commands, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "command.debug")
    public nonisolated static let emoji = "🔧"
    public nonisolated static let verbose = false

    public init() {}

    public var body: some Commands {
        CommandMenu(String(localized: "调试", bundle: .module)) {
            Button(String(localized: "打开 App Support 目录", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)打开 App Support 目录")
                }
                Self.openURL(Self.appSupportDirectory())
            }

            Button(String(localized: "打开容器目录", bundle: .module)) {
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

            Button(String(localized: "打开文档目录", bundle: .module)) {
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

            // 使用 StorageService.makeDataRootDirectory() 而非 LumiCore.dataRootDirectory：
            // DebugCommand 是 SwiftUI Commands,无法直接拿到 @EnvironmentObject,
            // 而 StorageService 是纯静态路径计算,等价于 v4.16.0 那个指向
            // `<AppSupport>/<bundleID>/db_<env>_v<major>/` 的 LumiCore.dataRootDirectory。
            // 注:重构后 LumiCore.dataRootDirectory 指向 `Core/` 子目录本身,
            // AppConfig.getDBFolderURL() 又因 AppConfig.configure 被移除而退化为
            // 单纯的 bundleID 目录,两者都不再等价于历史"数据库目录"的含义。
            Button(String(localized: "打开数据库目录", bundle: .module)) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)打开数据库目录")
                }
                // makeDataRootDirectory() 已改为 throws（启动期失败走 CrashedView）。
                // 此处是调试菜单的便利入口，非启动路径，用 try? 降级到 Application Support 目录。
                let url = (try? StorageService.makeDataRootDirectory()) ?? Self.appSupportDirectory()
                Self.openURL(url)
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
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
