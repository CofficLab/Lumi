import AppKit
import Sparkle
import SwiftUI

/// 主应用入口，负责应用生命周期管理
///
/// Lumi 应用的主入口点，使用 SwiftUI App 生命周期管理。
/// 通过 `@NSApplicationDelegateAdaptor` 集成 AppKit 代理，
/// 处理 macOS 特有的应用生命周期事件。
///
/// ## 应用结构
///
/// ```text
/// Lumi App
/// ├── WindowGroup (主窗口，可多开)
/// │   └── ContentLayout (主内容布局)
/// └── SettingsWindow (设置窗口)
///     └── SettingView (设置视图)
/// ```
///
/// ## 菜单命令
///
/// 应用提供以下菜单命令：
/// - DebugCommand: 调试相关命令
/// - SettingsCommand: 打开设置
/// - ConfigCommand: 配置命令
@main
struct CoreApp: App {
    /// macOS 应用代理，处理应用级别的生命周期事件
    ///
    /// MacAgent 负责：
    /// - 应用启动/终止
    /// - 激活/失活状态
    /// - 状态栏管理
    /// - 通知分发
    @NSApplicationDelegateAdaptor private var appDelegate: MacAgent

    /// 应用更新控制器
    private let updateController = UpdateController.shared

    var body: some Scene {
        // 主窗口（可多开）
        //
        // 禁用系统场景恢复：会话/项目/编辑器等状态均绑定稳定的 windowId 并由
        // 核心窗口状态存储写盘；若与 macOS 默认恢复叠加会重复开窗。
        WindowGroup("Lumi", id: AppConfig.mainWindowID, for: LumiWindowRoute.self) { route in
            MainWindowSceneContent(route: route)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1000, height: 800)
        .commands {
            DebugCommand()
            SettingsCommand()
            WindowCommand()
            ConfigCommand()
            EditorCommand()

            // 添加检查更新菜单项
            // 位于应用信息菜单之后
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updateController.updater)
            }
        }

        // 独立的设置窗口
        //
        // 单独的设置窗口，大小固定为 780x600。
        // 使用紧凑型工具栏样式，节省空间。
        Window("设置", id: AppConfig.settingsWindowID) {
            SettingView()
                .inRootView(container: WindowContainer(container: RootContainer.shared))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 780, height: 600)
    }
}

/// 检查更新视图
///
/// 显示在应用菜单中的"检查更新"按钮。
/// 点击后调用 Sparkle 框架检查更新。
struct CheckForUpdatesView: View {
    /// 更新检查视图模型
    @ObservedObject private var viewModel: CheckForUpdatesViewModel

    /// Sparkle 更新器实例
    private let updater: SPUUpdater

    /// 初始化检查更新视图
    ///
    /// - Parameter updater: Sparkle 更新器实例
    init(updater: SPUUpdater) {
        self.updater = updater
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("检查更新...", action: updater.checkForUpdates)
            // 当更新器正在检查或已检查完毕时禁用按钮
            .disabled(!viewModel.canCheckForUpdates)
    }
}

/// 检查更新视图模型
///
/// 负责管理更新检查的状态。
/// 监听 Sparkle 更新器的 canCheckForUpdates 属性。
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    /// 是否可以检查更新
    ///
    /// 当更新器正在进行检查时为 false，
    /// 检查完成后也会短暂为 false 以防止重复检查。
    @Published var canCheckForUpdates = false

    /// 初始化视图模型
    ///
    /// - Parameter updater: Sparkle 更新器实例
    init(updater: SPUUpdater) {
        // 监听更新器的 canCheckForUpdates 属性变化
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
}
