import SwiftUI

/// 主应用入口，负责应用生命周期管理和核心服务初始化
@main
struct CoreApp: App {
    /// macOS 应用代理，处理应用级别的生命周期事件
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        WindowGroup {
            ContentLayout()
                .inRootView()
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
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
