import OSLog
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 支持多窗口模式，每个窗口有独立的 WindowState
struct ContentView: View {
    /// emoji 标识符
    nonisolated static let emoji = "📱"
    /// 是否启用详细日志输出
    nonisolated static let verbose = false

    @EnvironmentObject var app: GlobalProvider
    @EnvironmentObject var pluginProvider: PluginProvider
    @EnvironmentObject var themeManager: MystiqueThemeManager

    /// 打开窗口的环境变量
    @Environment(\.openWindow) private var openWindow

    /// 当前配色方案（浅色/深色模式）
    @Environment(\.colorScheme) private var colorScheme

    /// 窗口级状态（每个窗口独立）
    @StateObject private var windowState: WindowState

    /// 默认选中的导航 ID
    var defaultNavigationId: String? = nil

    /// 默认侧边栏可见性
    var defaultSidebarVisibility: Bool? = nil

    /// 初始选中的会话 ID
    var initialConversationId: UUID? = nil

    /// 初始项目路径
    var initialProjectPath: String? = nil

    /// 初始化
    init(
        defaultNavigationId: String? = nil,
        defaultSidebarVisibility: Bool? = nil,
        initialConversationId: UUID? = nil,
        initialProjectPath: String? = nil
    ) {
        self.defaultNavigationId = defaultNavigationId
        self.defaultSidebarVisibility = defaultSidebarVisibility
        self.initialConversationId = initialConversationId
        self.initialProjectPath = initialProjectPath

        // 创建窗口状态
        _windowState = StateObject(wrappedValue: WindowState(
            conversationId: initialConversationId,
            projectPath: initialProjectPath
        ))
    }

    var body: some View {
        ContentViewBody(
            sidebarVisibility: $windowState.sidebarVisibility,
            columnVisibility: $windowState.columnVisibility,
            app: app,
            pluginProvider: pluginProvider,
            themeManager: themeManager,
            content: {
                Group {
                    switch windowState.selectedMode {
                    case .app:
                        AppModeContentView(sidebarVisibility: $windowState.sidebarVisibility)
                    case .agent:
                        AgentModeContentView(sidebarVisibility: $windowState.sidebarVisibility)
                    }
                }
            },
            openSettings: openSettings,
            openPluginSettings: openPluginSettings,
            onAppear: onAppear,
            onChangeColumnVisibility: onChangeColumnVisibility
        )
        .environment(\.windowState, windowState)
    }
}

struct ContentViewBody<Content: View>: View {
    @Binding var sidebarVisibility: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var app: GlobalProvider
    @ObservedObject var pluginProvider: PluginProvider
    @ObservedObject var themeManager: MystiqueThemeManager
    let content: Content
    let openSettings: () -> Void
    let openPluginSettings: () -> Void
    let onAppear: () -> Void
    let onChangeColumnVisibility: () -> Void

    init(
        sidebarVisibility: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        app: GlobalProvider,
        pluginProvider: PluginProvider,
        themeManager: MystiqueThemeManager,
        @ViewBuilder content: () -> Content,
        openSettings: @escaping () -> Void,
        openPluginSettings: @escaping () -> Void,
        onAppear: @escaping () -> Void,
        onChangeColumnVisibility: @escaping () -> Void
    ) {
        self._sidebarVisibility = sidebarVisibility
        self._columnVisibility = columnVisibility
        self.app = app
        self.pluginProvider = pluginProvider
        self.themeManager = themeManager
        self.content = content()
        self.openSettings = openSettings
        self.openPluginSettings = openPluginSettings
        self.onAppear = onAppear
        self.onChangeColumnVisibility = onChangeColumnVisibility
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onOpenSettings(perform: openSettings)
            .onOpenPluginSettings(perform: openPluginSettings)
            .background {
                GeometryReader { proxy in
                    themeManager.currentVariant.theme.makeGlobalBackground(proxy: proxy)
                }
                .ignoresSafeArea()
            }
            .onAppear(perform: onAppear)
            .onChange(of: columnVisibility) { _, _ in
                onChangeColumnVisibility()
            }
            .overlay(alignment: .bottom) {
                pluginProvider.getRootViewWrapper(content: { EmptyView() })
            }
    }
}

// MARK: - Event Handler

extension ContentView {
    /// 视图出现时的事件处理
    func onAppear() {
        // 注册窗口到 WindowManager
        WindowManager.shared.registerWindow(windowState)

        // 配置窗口样式
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.last {
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)

            // 关联 NSWindow 和窗口状态
            WindowManager.shared.associateWindow(window, with: windowState.id)

            // 设置窗口标题
            window.title = windowState.title
        }

        // 应用默认配置
        if let defaultNavigationId = defaultNavigationId {
            if Self.verbose {
                os_log("\(Self.emoji) Setting default navigation to: \(defaultNavigationId)")
            }
            app.selectedNavigationId = defaultNavigationId
        }

        if let defaultSidebarVisibility = defaultSidebarVisibility {
            windowState.sidebarVisibility = defaultSidebarVisibility
        }

        // 监听窗口标题变化并更新 NSWindow 标题
        setupWindowTitleObserver()
    }

    /// 设置窗口标题观察者
    private func setupWindowTitleObserver() {
        let windowId = windowState.id
        windowState.$title
            .receive(on: DispatchQueue.main)
            .sink { [self] newTitle in
                // 更新 NSWindow 标题
                if let window = NSApplication.shared.windows.first(where: { _ in
                    WindowManager.shared.getWindowState(windowId) != nil
                }) {
                    window.title = newTitle
                }
            }
            .store(in: &windowState.cancellables)
    }

    /// 处理列可见性变更事件
    func onChangeColumnVisibility() {
        if windowState.columnVisibility == .detailOnly {
            windowState.sidebarVisibility = false
        } else {
            windowState.sidebarVisibility = true
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
        .inRootView()
        .withDebugBar()
}
