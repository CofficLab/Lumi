import AppKit
import MagicKit
import SwiftUI

/// 调试命令：在应用菜单中添加调试相关的功能入口
struct DebugCommand: Commands, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🐛"

    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    var body: some Commands {
        SidebarCommands()

        #if os(macOS)
            CommandMenu("调试") {
                Button("打开App Support目录") {
                    let dir = AppConfig.getCurrentAppSupportDir()
                    NSWorkspace.shared.open(dir)
                }

                Button("打开容器目录") {
                    guard let dir = AppConfig.localContainer else {
                        // 显示错误提示
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "打开容器目录出错"
                        errorAlert.informativeText = "容器目录不存在"
                        errorAlert.alertStyle = .critical
                        errorAlert.addButton(withTitle: "好的")
                        errorAlert.runModal()

                        return
                    }

                    NSWorkspace.shared.open(dir)
                }

                Button("打开文档目录") {
                    guard let dir = AppConfig.localDocumentsDir else {
                        // 显示错误提示
                        let errorAlert = NSAlert()
                        errorAlert.messageText = "打开文档目录出错"
                        errorAlert.informativeText = "文档目录不存在"
                        errorAlert.alertStyle = .critical
                        errorAlert.addButton(withTitle: "好的")
                        errorAlert.runModal()

                        return
                    }

                    NSWorkspace.shared.open(dir)
                }

                Button("打开数据库目录") {
                    let dir = AppConfig.getDBFolderURL()
                    NSWorkspace.shared.open(dir)
                }
            }
        #endif
    }
}

// MARK: - Preview

#Preview("Debug Command") {
    Text("Debug Command Preview")
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
