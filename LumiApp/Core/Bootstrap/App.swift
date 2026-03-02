import AppKit
import MagicKit
import SwiftUI
import Sparkle

/// 主应用入口，负责应用生命周期管理和核心服务初始化
@main
struct CoreApp: App {
    /// macOS 应用代理，处理应用级别的生命周期事件
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    /// Sparkle 更新控制器
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
            
            // 添加检查更新菜单项
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
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

/// 检查更新视图
struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("检查更新...", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

/// 检查更新视图模型
/// 负责管理更新检查的状态
final class CheckForUpdatesViewModel: ObservableObject {
    /// 是否可以检查更新
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
