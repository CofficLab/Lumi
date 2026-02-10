import SwiftUI
import MagicKit

/// 配置命令：在应用菜单中添加配置相关的功能入口
struct ConfigCommand: Commands, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "⚙️"

    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    var body: some Commands {
        #if os(macOS)
        CommandMenu("配置") {
            Button("插件管理...") {
                // 发送打开插件设置的通知
                NotificationCenter.postOpenPluginSettings()
            }
            .keyboardShortcut("P", modifiers: [.command, .shift])

            Divider()

            Button("偏好设置...") {
                // 发送打开设置的通知
                NotificationCenter.postOpenSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        #endif
    }
}
