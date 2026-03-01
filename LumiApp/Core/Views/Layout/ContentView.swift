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
        Group {
            switch app.selectedMode {
            case .app:
                // 应用模式：使用固定的侧边栏布局
                appModeLayout
            case .agent:
                // Agent 模式：侧边栏由插件提供
                agentModeLayout
            }
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

    // MARK: - App Mode Layout

    /// 应用模式布局（固定侧边栏）
    private var appModeLayout: some View {
        HStack(spacing: 0) {
            // 侧边栏
            if sidebarVisibility {
                VStack(spacing: 0) {
                    // 模式切换器
                    modeSwitcher
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.top, 32)
                        .padding(.bottom, DesignTokens.Spacing.sm)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // 应用模式侧边栏
                    Sidebar()
                }
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
    }

    // MARK: - Agent Mode Layout

    /// Agent 模式布局（插件提供侧边栏和详情视图）
    private var agentModeLayout: some View {
        HStack(spacing: 0) {
            // 侧边栏
            if sidebarVisibility {
                VStack(spacing: 0) {
                    // 模式切换器
                    modeSwitcher
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.top, 32)
                        .padding(.bottom, DesignTokens.Spacing.sm)

                    Divider()
                        .background(Color.white.opacity(0.1))

                    // 插件提供的侧边栏视图（垂直堆叠）
                    pluginSidebar
                }
                .frame(width: 220)

                // 侧边栏与内容区的分隔线
                Rectangle()
                    .fill(SwiftUI.Color.white.opacity(0.1))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }

            // 内容区域：显示插件提供的详情视图
            agentDetailContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if Self.verbose {
                let views = pluginProvider.getSidebarViews()
                os_log("\(Self.emoji) Agent Mode: 侧边栏视图数量=\(views.count)")
            }
        }
    }

    /// Agent 模式的详情内容视图（显示插件提供的详情视图）
    @ViewBuilder
    private func agentDetailContent() -> some View {
        let detailViews = pluginProvider.getDetailViews()
        Group {
            if detailViews.isEmpty {
                // 如果没有插件提供详情视图，显示默认内容
                defaultDetailView
            } else {
                // 显示所有插件提供的详情视图
                VStack(spacing: 0) {
                    ForEach(Array(detailViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
    }

    /// 插件提供的侧边栏视图（多个插件的侧边栏从上到下垂直堆叠）
    private var pluginSidebar: some View {
        let sidebarViews = pluginProvider.getSidebarViews()
        return Group {
            if sidebarViews.isEmpty {
                // 如果没有插件提供侧边栏视图，显示一个默认的侧边栏
                VStack(spacing: 8) {
                    Text("Agent 模式侧边栏")
                        .font(.headline)
                        .padding()
                    Text("暂无插件提供侧边栏视图")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sidebarViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
            }
        }
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

    // MARK: - Mode Switcher

    /// 模式切换器
    private var modeSwitcher: some View {
        Picker("模式", selection: Binding(
            get: { app.selectedMode },
            set: {
                app.selectedMode = $0
                pluginProvider.selectedMode = $0
            }
        )) {
            ForEach(AppMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
