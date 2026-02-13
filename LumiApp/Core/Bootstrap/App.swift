import SwiftUI

/// 主应用入口，负责应用生命周期管理和核心服务初始化
@main
struct CoreApp: App {
    /// macOS 应用代理，处理应用级别的生命周期事件
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    var body: some Scene {
        // 主窗口
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

        // 独立的设置窗口
        Window("设置", id: SettingsWindowID.settings) {
            SettingView()
                .inRootView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 780, height: 600)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
