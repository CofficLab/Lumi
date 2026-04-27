import AppKit
import MagicKit
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 布局完全由各插件自行决定，核心只提供活动栏 + 面板内容区。
/// 不再有全局右侧栏，右侧栏由各插件在自己的面板视图内自行管理。
struct ContentView: View, SuperLog {
    nonisolated static let emoji = "📱"
    nonisolated static let verbose: Bool = false

    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var providerRegistry: LLMProviderRegistry
    @EnvironmentObject var layoutVM: LayoutVM

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    /// 窗口级状态（每个窗口独立）
    @StateObject private var windowState: WindowState

    /// 默认侧边栏可见性
    var defaultSidebarVisibility: Bool?

    /// 初始选中的会话 ID
    var initialConversationId: UUID?

    /// 初始项目路径
    var initialProjectPath: String?

    init(
        defaultSidebarVisibility: Bool? = nil,
        initialConversationId: UUID? = nil,
        initialProjectPath: String? = nil
    ) {
        self.defaultSidebarVisibility = defaultSidebarVisibility
        self.initialConversationId = initialConversationId
        self.initialProjectPath = initialProjectPath

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
                VStack(spacing: 0) {
                    mainContent
                    StatusBar()
                }
            },
            openSettings: openSettings,
            openPluginSettings: openPluginSettings,
            onAppear: onAppear,
            onChangeColumnVisibility: onChangeColumnVisibility
        )
        .toolbar {
            let leadingViews = pluginProvider.getToolbarLeadingViews()
            let trailingViews = pluginProvider.getToolbarTrailingViews()

            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 0) {
                    ForEach(Array(leadingViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ToolbarItemGroup(placement: .cancellationAction) {
                ForEach(Array(trailingViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
        .environment(\.windowState, windowState)
    }

    // MARK: - Main Content

    /// 当前选中的面板是否需要右侧栏
    private var currentPanelNeedsSidebar: Bool {
        let panelItems = pluginProvider.getPanelItems()
        let selectedId = layoutVM.selectedAgentSidebarTabId
        let selected = panelItems.first(where: { $0.id == selectedId }) ?? panelItems.first
        return selected?.panelNeedsSidebar ?? true
    }

    /// 主内容区域：活动栏 + 面板 + 右侧栏（按当前面板需求动态显示）
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if providerRegistry.providerTypes.isEmpty {
                ActivityBar()
                AgentModeUnavailableGuideView()
            } else {
                let sidebarViews = pluginProvider.getSidebarViews()
                let shouldShowSidebar = !sidebarViews.isEmpty && currentPanelNeedsSidebar

                if shouldShowSidebar {
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView()

                        // 右侧栏：聚合所有插件提供的侧边栏视图
                        RightSidebarContainerView(views: sidebarViews)
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: "Unified_MainSplit"))
                } else {
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView()
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: "Unified_MainSplit"))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content View Body

struct ContentViewBody<Content: View>: View {
    @Binding var sidebarVisibility: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var app: GlobalVM
    @ObservedObject var pluginProvider: PluginVM
    @ObservedObject var themeManager: ThemeManager
    let content: Content
    let openSettings: () -> Void
    let openPluginSettings: () -> Void
    let onAppear: () -> Void
    let onChangeColumnVisibility: () -> Void

    init(
        sidebarVisibility: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        app: GlobalVM,
        pluginProvider: PluginVM,
        themeManager: ThemeManager,
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
            .onOpenSettings(perform: openSettings)
            .onOpenPluginSettings(perform: openPluginSettings)
            .background {
                GeometryReader { proxy in
                    themeManager.activeAppTheme.makeGlobalBackground(proxy: proxy)
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
    func onAppear() {
        // 注册窗口到 WindowManager
        WindowManager.shared.registerWindow(windowState)

        // 配置窗口标题
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.last {
            WindowManager.shared.associateWindow(window, with: windowState.id)
            window.title = windowState.title
        }

        // 应用默认配置
        if let defaultSidebarVisibility = defaultSidebarVisibility {
            windowState.sidebarVisibility = defaultSidebarVisibility
        }

        setupWindowTitleObserver()
    }

    private func setupWindowTitleObserver() {
        let windowId = windowState.id
        windowState.$title
            .receive(on: DispatchQueue.main)
            .sink { newTitle in
                if let window = NSApplication.shared.windows.first(where: { _ in
                    WindowManager.shared.getWindowState(windowId) != nil
                }) {
                    window.title = newTitle
                }
            }
            .store(in: &windowState.cancellables)
    }

    func onChangeColumnVisibility() {
        if windowState.columnVisibility == .detailOnly {
            windowState.sidebarVisibility = false
        } else {
            windowState.sidebarVisibility = true
        }
    }

    func openSettings() {
        openWindow(id: SettingsWindowID.settings)
    }

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
