import OSLog
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
struct ContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "📱"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    @EnvironmentObject var app: AppProvider
    @EnvironmentObject var pluginProvider: PluginProvider
    @EnvironmentObject var themeManager: MystiqueThemeManager

    /// 打开窗口的环境变量
    @Environment(\.openWindow) private var openWindow

    /// 当前配色方案（浅色/深色模式）
    @Environment(\.colorScheme) private var colorScheme

    /// 导航分栏视图的列可见性状态
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 侧边栏是否可见
    @State private var sidebarVisibility = true

    /// 默认选中的导航 ID
    var defaultNavigationId: String? = nil

    /// 默认侧边栏可见性
    var defaultSidebarVisibility: Bool? = nil

    var body: some View {
        Group {
            switch app.selectedMode {
            case .app:
                AppModeContentView(sidebarVisibility: $sidebarVisibility)
            case .agent:
                AgentModeContentView(sidebarVisibility: $sidebarVisibility)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onOpenSettings(perform: openSettings)
        .onOpenPluginSettings(perform: openPluginSettings)
        // 全局背景光晕效果
        .background {
            GeometryReader { proxy in
                themeManager.currentVariant.theme.makeGlobalBackground(proxy: proxy)
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: onAppear)
        .onChange(of: columnVisibility, onChangeColumnVisibility)
    }
}

// MARK: - Event Handler

extension ContentView {
    /// 视图出现时的事件处理
    func onAppear() {
        // 配置窗口样式
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
        }

        // 应用默认配置
        if let defaultNavigationId = defaultNavigationId {
            if Self.verbose {
                os_log("\(Self.emoji) Setting default navigation to: \(defaultNavigationId)")
            }
            app.selectedNavigationId = defaultNavigationId
        }

        if let defaultSidebarVisibility = defaultSidebarVisibility {
            sidebarVisibility = defaultSidebarVisibility
        }
    }

    /// 处理列可见性变更事件
    func onChangeColumnVisibility() {
        if columnVisibility == .detailOnly {
            sidebarVisibility = false
        } else {
            sidebarVisibility = true
        }
    }

    /// 打开设置视图（在独立窗口中）
    func openSettings() {
        openWindow(id: SettingsWindowID.settings)
    }

    /// 打开插件设置视图（在独立窗口中）
    func openPluginSettings() {
        openWindow(id: SettingsWindowID.settings)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView("Preview")
        .withDebugBar()
}
