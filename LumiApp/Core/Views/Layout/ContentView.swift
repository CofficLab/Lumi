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

    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var themeVM: ThemeVM
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
            pluginProvider: pluginProvider,
            themeVM: themeVM,
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
            let centerViews = pluginProvider.getToolbarCenterViews()
            let trailingViews = pluginProvider.getToolbarTrailingViews()

            ToolbarItemGroup(placement: .navigation) {
                ForEach(Array(leadingViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }

            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 8) {
                    ForEach(Array(centerViews.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            ToolbarItemGroup(placement: .cancellationAction) {
                ForEach(Array(trailingViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
        .environment(\.windowState, windowState)
    }

    /// 主内容区域：活动栏 + Rail + 面板 + 右侧栏（只要有插件提供右侧视图就显示）
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if providerRegistry.providerTypes.isEmpty {
                HSplitView {
                    ActivityBar()
                    AgentModeUnavailableGuideView()
                }
                .background(SplitViewAutosaveConfigurator(autosaveName: "Unified_MainSplit_noProvider"))
            } else {
                let sidebarViews = pluginProvider.getSidebarViews()
                let hasRail = pluginProvider.hasRailTabs()

                // 根据分栏组合生成布局签名，避免不同分栏数共享 autosaveName 导致位置错乱
                let layoutSignature = Self.layoutSignature(hasRail: hasRail, hasSidebar: !sidebarViews.isEmpty)
                let autosaveName = "Unified_MainSplit_\(layoutSignature)"

                if !sidebarViews.isEmpty && hasRail {
                    // 4 栏: ActivityBar(固定) | Rail | Panel | RightSidebar
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // Rail 栏（活动栏与面板之间的辅助栏，全局最多一个插件提供）
                        RailView()
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.Rail",
                                columnIndex: 1
                            ))

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView().frame(maxWidth: .infinity)

                        // 右侧栏：聚合所有插件提供的侧边栏视图
                        RightSidebarContainerView(views: sidebarViews)
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.RightSidebar",
                                columnIndex: 3
                            ))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else if !sidebarViews.isEmpty {
                    // 3 栏: ActivityBar(固定) | Panel | RightSidebar
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView().frame(maxWidth: .infinity)

                        // 右侧栏：聚合所有插件提供的侧边栏视图
                        RightSidebarContainerView(views: sidebarViews)
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.RightSidebar",
                                columnIndex: 2
                            ))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else if hasRail {
                    // 3 栏: ActivityBar(固定) | Rail | Panel
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // Rail 栏（活动栏与面板之间的辅助栏，全局最多一个插件提供）
                        RailView()
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.Rail",
                                columnIndex: 1
                            ))

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView().frame(maxWidth: .infinity)
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else {
                    // 2 栏: ActivityBar(固定) | Panel
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView().frame(maxWidth: .infinity)
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Layout Helpers

    /// 根据分栏组合生成布局签名
    /// - Parameters:
    ///   - hasRail: 是否有 Rail 栏
    ///   - hasSidebar: 是否有右侧栏
    /// - Returns: 布局签名字符串，如 "SRB"、"S" 等
    private static func layoutSignature(hasRail: Bool, hasSidebar: Bool) -> String {
        var signature = ""
        if hasSidebar { signature += "S" }
        if hasRail { signature += "R" }
        // B = Base (always present: ActivityBar + Panel)
        signature += "B"
        return signature
    }
}

// MARK: - Content View Body

struct ContentViewBody<Content: View>: View {
    @Binding var sidebarVisibility: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var pluginProvider: PluginVM
    @ObservedObject var themeVM: ThemeVM
    let content: Content
    let openSettings: () -> Void
    let openPluginSettings: () -> Void
    let onAppear: () -> Void
    let onChangeColumnVisibility: () -> Void

    init(
        sidebarVisibility: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        pluginProvider: PluginVM,
        themeVM: ThemeVM,
        @ViewBuilder content: () -> Content,
        openSettings: @escaping () -> Void,
        openPluginSettings: @escaping () -> Void,
        onAppear: @escaping () -> Void,
        onChangeColumnVisibility: @escaping () -> Void
    ) {
        self._sidebarVisibility = sidebarVisibility
        self._columnVisibility = columnVisibility
        self.pluginProvider = pluginProvider
        self.themeVM = themeVM
        self.content = content()
        self.openSettings = openSettings
        self.openPluginSettings = openPluginSettings
        self.onAppear = onAppear
        self.onChangeColumnVisibility = onChangeColumnVisibility
    }

    /// 根据当前应用主题计算应使用的 colorScheme，
    /// 使得 `Color.adaptive(light:dark:)` 等基于 colorScheme 的颜色
    /// 能与主题保持一致（例如 One Dark 深色主题在浅色系统模式下也使用深色文字色）。
    private var preferredColorScheme: ColorScheme {
        themeVM.activeAppTheme.isDarkTheme ? .dark : .light
    }

    var body: some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .onOpenSettings(perform: openSettings)
            .onOpenPluginSettings(perform: openPluginSettings)
            .background {
                GeometryReader { proxy in
                    themeVM.activeAppTheme.makeGlobalBackground(proxy: proxy)
                }
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
