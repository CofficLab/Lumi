import AppKit
import Combine
import LumiUI
import MagicKit
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 布局完全由各插件自行决定，核心只提供活动栏 + 面板内容区。
/// 不再有全局右侧栏，右侧栏由各插件在自己的面板视图内自行管理。
///
/// ## 多窗口架构
///
/// ContentView 从 `WindowScope` 获取窗口级 VM，每个窗口拥有独立的 VM 实例。
/// 不再需要双向同步，窗口状态天然隔离。
struct ContentView: View, SuperLog {
    nonisolated static let emoji = "📱"
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var themeVM: AppThemeVM
    @EnvironmentObject var providerRegistry: LLMProviderRegistry
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @EnvironmentObject var conversationVM: WindowConversationVM
    @EnvironmentObject var projectVM: WindowProjectVM

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.windowScope) private var windowScope

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
    }

    var body: some View {
        Group {
            if let scope = windowScope {
                contentViewBody(scope: scope)
            } else {
                // 无 WindowScope 时显示空白（不应该发生）
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func contentViewBody(scope: WindowScope) -> some View {
        ContentViewBody(
            sidebarVisibility: Binding(
                get: { scope.sidebarVisibility },
                set: { scope.sidebarVisibility = $0 }
            ),
            columnVisibility: Binding(
                get: { scope.columnVisibility },
                set: { scope.columnVisibility = $0 }
            ),
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
            onAppear: { onAppear(scope: scope) },
            onChangeColumnVisibility: { onChangeColumnVisibility(scope: scope) }
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

            if !centerViews.isEmpty {
                ToolbarItemGroup(placement: .principal) {
                    HStack(spacing: 8) {
                        ForEach(Array(centerViews.enumerated()), id: \.offset) { _, view in
                            view
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            ToolbarItemGroup(placement: .cancellationAction) {
                ForEach(Array(trailingViews.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        }
        .environment(\.windowScope, scope)
        .background {
            WindowAccessor { window in
                RootContainer.shared.windowManagerVM.associateWindow(window, with: scope.id)
                window.title = scope.title
            }
        }
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
                let sidebarSections = pluginProvider.getSidebarSections()
                let hasRail = pluginProvider.hasRailTabs()

                let layoutSignature = Self.layoutSignature(hasRail: hasRail, hasSidebar: !sidebarSections.isEmpty)
                let autosaveName = "Unified_MainSplit_\(layoutSignature)"

                if !sidebarSections.isEmpty && hasRail {
                    HSplitView {
                        ActivityBar()
                        RailView()
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.Rail",
                                columnIndex: 1
                            ))
                        PanelContentView().frame(maxWidth: .infinity)
                        RightSidebarContainerView(sections: sidebarSections)
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.RightSidebar",
                                columnIndex: 3
                            ))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else if !sidebarSections.isEmpty {
                    HSplitView {
                        ActivityBar()
                        PanelContentView().frame(maxWidth: .infinity)
                        RightSidebarContainerView(sections: sidebarSections)
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.RightSidebar",
                                columnIndex: 2
                            ))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else if hasRail {
                    HSplitView {
                        ActivityBar()
                        RailView()
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.Rail",
                                columnIndex: 1
                            ))
                        PanelContentView().frame(maxWidth: .infinity)
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else {
                    HSplitView {
                        ActivityBar()
                        PanelContentView().frame(maxWidth: .infinity)
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Layout Helpers

    private static func layoutSignature(hasRail: Bool, hasSidebar: Bool) -> String {
        var signature = ""
        if hasSidebar { signature += "S" }
        if hasRail { signature += "R" }
        signature += "B"
        return signature
    }
}

// MARK: - Content View Body

struct ContentViewBody<Content: View>: View {
    @LumiMotionPreferenceReader private var motionPreference

    @Binding var sidebarVisibility: Bool
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @ObservedObject var pluginProvider: AppPluginVM
    @ObservedObject var themeVM: AppThemeVM
    let content: Content
    let openSettings: () -> Void
    let openPluginSettings: () -> Void
    let onAppear: () -> Void
    let onChangeColumnVisibility: () -> Void

    init(
        sidebarVisibility: Binding<Bool>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        pluginProvider: AppPluginVM,
        themeVM: AppThemeVM,
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
            .animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference), value: themeVM.currentThemeId)
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
    func onAppear(scope: WindowScope) {
        // 注册窗口到 WindowManager
        RootContainer.shared.windowManagerVM.registerScope(scope)

        // 应用默认配置
        if let defaultSidebarVisibility = defaultSidebarVisibility {
            scope.sidebarVisibility = defaultSidebarVisibility
        }

        // 设置标题同步
        setupWindowTitleObserver(scope: scope)
    }

    private func setupWindowTitleObserver(scope: WindowScope) {
        scope.$title
            .receive(on: DispatchQueue.main)
            .sink { newTitle in
                if let window = RootContainer.shared.windowManagerVM.window(for: scope.id) {
                    window.title = newTitle
                }
            }
            .store(in: &scope.cancellables)
    }

    func onChangeColumnVisibility(scope: WindowScope) {
        if scope.columnVisibility == .detailOnly {
            scope.sidebarVisibility = false
        } else {
            scope.sidebarVisibility = true
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
        .inRootView(scope: WindowScope(container: RootContainer.shared))
        .withDebugBar()
}
