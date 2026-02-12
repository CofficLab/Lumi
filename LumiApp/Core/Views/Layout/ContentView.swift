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

    /// 当前配色方案（浅色/深色模式）
    @Environment(\.colorScheme) private var colorScheme

    /// 导航分栏视图的列可见性状态
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// 当前选中的标签页
    @State private var tab: String = "main"

    /// 工具栏是否可见
    @State private var toolbarVisibility = false

    /// 标签页选择器是否可见
    @State private var tabPickerVisibility = false

    /// 侧边栏是否可见
    @State private var sidebarVisibility = true

    /// 设置视图是否显示
    @State private var showSettings = false
    
    /// 设置视图当前选中的标签
    @State private var settingsTab: SettingView.SettingTab = .about

    /// 默认选中的标签页
    var defaultTab: String? = nil

    /// 默认列可见性
    var defaultColumnVisibility: NavigationSplitViewVisibility? = nil

    /// 默认工具栏可见性
    var defaultToolbarVisibility: Bool? = nil

    /// 默认标签页可见性
    var defaultTabVisibility: Bool? = nil

    /// 默认选中的导航 ID
    var defaultNavigationId: String? = nil

    /// 缓存工具栏前导视图的插件和视图对
    @State private var toolbarLeadingViews: [(plugin: SuperPlugin, view: AnyView)] = []

    /// 缓存工具栏后置视图的插件和视图对
    @State private var toolbarTrailingViews: [(plugin: SuperPlugin, view: AnyView)] = []

    var body: some View {
        Group {
            contentLayout()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingView(defaultTab: settingsTab)
        }
        .onOpenSettings(perform: openSettings)
        .onOpenPluginSettings(perform: openPluginSettings)
        .onReceive(NotificationCenter.default.publisher(for: .pluginSettingsChanged)) { _ in
            if Self.verbose {
                os_log("\(Self.emoji) ⚙️ Plugin settings changed, updating cached views")
            }
            updateCachedViews()
        }
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
            }
            
            // 内容区域
            detailContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignTokens.Color.adaptive.deepBackground(for: colorScheme))
        // 全局背景光晕效果
        .background {
            GeometryReader { proxy in
                // 主光晕
                Circle()
                    .fill(Themes.Gradients.mysticGlow)
                    .frame(width: 600, height: 600)
                    .blur(radius: 120)
                    .offset(x: -200, y: -200)

                // 次光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Themes.Colors.glow.intense,
                                Themes.Colors.glow.medium,
                                SwiftUI.Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .blur(radius: 120)
                    .position(x: proxy.size.width, y: proxy.size.height)
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: onAppear)
        .onChange(of: tab, onChangeOfTab)
        .onChange(of: columnVisibility, onChangeColumnVisibility)
        .onChange(of: pluginProvider.plugins.count, onPluginsLoaded)
        .toolbarVisibility(toolbarVisibility ? .visible : .hidden)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ForEach(toolbarLeadingViews, id: \.plugin.instanceLabel) { item in
                    item.view
                }
            }

            if tabPickerVisibility {
                ToolbarItem(placement: .principal) {
                    Picker("选择标签", selection: $tab) {
                        Text("主页").tag("main")
                        Text("设置").tag("settings")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
            }

            ToolbarItemGroup(placement: .cancellationAction) {
                ForEach(toolbarTrailingViews, id: \.plugin.instanceLabel) { item in
                    item.view
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
}

// MARK: - Event Handler

extension ContentView {
    /// 更新缓存的视图
    func updateCachedViews() {
        if Self.verbose {
            os_log("\(Self.emoji) 🔄 Updating cached views")
        }

        // 更新工具栏前导视图
        toolbarLeadingViews = pluginProvider.plugins.compactMap { plugin in
            if let view = plugin.addToolBarLeadingView() {
                return (plugin, view)
            }
            return nil
        }

        // 更新工具栏后置视图
        toolbarTrailingViews = pluginProvider.plugins.compactMap { plugin in
            if let view = plugin.addToolBarTrailingView() {
                return (plugin, view)
            }
            return nil
        }

        if Self.verbose {
            os_log("\(Self.emoji) ✅ Cached views updated: \(toolbarLeadingViews.count) leading, \(toolbarTrailingViews.count) trailing")
        }
    }

    /// 视图出现时的事件处理
    func onAppear() {
        // 配置窗口样式
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        
        // Delay state updates to avoid "Publishing changes during view update" warning
        DispatchQueue.main.async {
            // 如果提供了默认的，则使用默认的
            // 否则使用存储的

            if let d = defaultColumnVisibility {
                self.columnVisibility = d
            } else {
                self.columnVisibility = sidebarVisibility ? .all : .detailOnly
            }

            if let d = defaultTab {
                if Self.verbose {
                    os_log("\(Self.emoji) Setting default tab to: \(d)")
                }
                self.tab = d
            } else {
                if Self.verbose {
                    os_log("\(Self.emoji) No default tab provided, using 'main'")
                }
                self.tab = "main"
            }

            if let d = defaultToolbarVisibility {
                self.toolbarVisibility = d
            }

            if let d = defaultTabVisibility {
                self.tabPickerVisibility = d
            }

            if let d = defaultNavigationId {
                if Self.verbose {
                    os_log("\(Self.emoji) Setting default navigation to: \(d)")
                }
                app.selectedNavigationId = d
            }

            // 初始化缓存的视图
            updateCachedViews()
        }
    }

    /// 处理标签页变更事件
    func onChangeOfTab() {
        updateCachedViews()
    }

    /// 处理列可见性变更事件
    func onChangeColumnVisibility() {
        if columnVisibility == .detailOnly {
            sidebarVisibility = false
        } else {
            sidebarVisibility = true
        }
    }

    /// 处理插件加载完成事件
    func onPluginsLoaded() {
        // 当插件列表从空变为非空时，更新缓存的视图
        if !pluginProvider.plugins.isEmpty {
            if Self.verbose {
                os_log("\(Self.emoji) 🔌 Plugins loaded, updating cached views")
            }
            updateCachedViews()
        }
    }

    /// 打开设置视图
    func openSettings() {
        showSettings = true
    }

    /// 打开插件设置视图
    func openPluginSettings() {
        settingsTab = .plugins
        showSettings = true
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
