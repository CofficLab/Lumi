import MagicKit
import OSLog
import SwiftUI

/// 主应用入口，负责应用生命周期管理和核心服务初始化
@main
struct CoreApp: App, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🍎"

    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    /// macOS 应用代理，处理应用级别的生命周期事件
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        WindowGroup {
            ContentLayout()
                .inRootView()
        }
        .windowStyle(.titleBar)
        .commands {
            DebugCommand()
            SettingsCommand()
            ConfigCommand()
        }
    }
}

// MARK: - Preview

#Preview("Test") {
    Text("Hello")
}
