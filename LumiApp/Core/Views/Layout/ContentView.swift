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
            contentLayout()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onOpenSettings(perform: openSettings)
        .onOpenPluginSettings(perform: openPluginSettings)
    }
}

// MARK: - View

extension ContentView {
    /// 创建主布局视图
    /// - Returns: 配置好的主布局视图
    private func contentLayout() -> some View {
        HStack(spacing: 0) {
            // 侧边栏
            if sidebarVisibility {
                Sidebar()
                    .frame(width: 220)

                // 侧边栏与内容区的微妙分隔线
                Rectangle()
                    .fill(SwiftUI.Color.white.opacity(0.1))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }

            // 内容区域
            detailContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

    /// 创建详情内容视图
    /// - Returns: 详情内容视图
    @ViewBuilder
    private func detailContent() -> some View {
        VStack(spacing: 0) {
            // 显示当前选中的导航内容
            app.getCurrentNavigationView(pluginProvider: pluginProvider)
        }
        .frame(maxHeight: .infinity)
    }

    /// 默认详情视图（当没有插件提供详情视图时显示）
    private var defaultDetailView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("欢迎使用 Lumi")
                .font(.title)
                .fontWeight(.bold)
            Text("请从侧边栏选择一个导航入口")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
//        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
