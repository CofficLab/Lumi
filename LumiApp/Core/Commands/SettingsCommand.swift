import AppKit
import MagicKit
import SwiftUI

/// 设置命令：在应用菜单中添加设置入口
struct SettingsCommand: Commands, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "⚙️"

    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    var body: some Commands {
        #if os(macOS)
            CommandGroup(after: .appInfo) {
                Button("设置...") {
                    // 发送打开设置的通知
                    NotificationCenter.postOpenSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        #endif
    }
}

// MARK: - Preview

#Preview("Settings Command") {
    Text("Settings Command Preview")
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
