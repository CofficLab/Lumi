import LumiCoreKit
import AppKit
import Combine
import LumiUI
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 布局完全由各插件自行决定，核心只提供活动栏 + 面板内容区。
/// 不再有全局右侧栏，右侧栏由各插件在自己的面板视图内自行管理。
///
/// ## 多窗口架构
///
/// ContentView 从 `WindowContainer` 获取窗口级 VM，每个窗口拥有独立的 VM 实例。
/// 不再需要双向同步，窗口状态天然隔离。
struct ContentView: View, SuperLog {
    nonisolated static let emoji = "📱"
    nonisolated static var verbose: Bool { false }

    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var themeVM: AppThemeVM
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @EnvironmentObject var conversationVM: WindowConversationVM
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject private var messageRendererVM: AppMessageRendererVM

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.windowContainer) private var windowContainer

    /// 默认侧边栏可见性
    var defaultSidebarVisibility: Bool?

    /// 初始项目路径
    var initialProjectPath: String?

    init(
        defaultSidebarVisibility: Bool? = nil,
        initialProjectPath: String? = nil
    ) {
        self.defaultSidebarVisibility = defaultSidebarVisibility
        self.initialProjectPath = initialProjectPath
    }

    var body: some View {
        Group {
            if let container = windowContainer {
                contentViewBody(container: container)
            } else {
                // 无 WindowContainer 时显示空白（不应该发生）
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func contentViewBody(container: WindowContainer) -> some View {
        ContentViewBody(
            sidebarVisibility: Binding(
                get: { container.sidebarVisibility },
                set: { container.sidebarVisibility = $0 }
            ),
            columnVisibility: Binding(
                get: { container.columnVisibility },
                set: { container.columnVisibility = $0 }
            ),
            pluginProvider: pluginProvider,
            themeVM: themeVM,
            content: {
                VStack(spacing: 0) {
                    AppTitleToolbar()
                    mainContent
                    StatusBar()
                }
            },
            openSettings: openSettings,
            openPluginSettings: openPluginSettings,
            onAppear: { onAppear(container: container) },
            onChangeColumnVisibility: { onChangeColumnVisibility(container: container) }
        )
        .environment(\.windowContainer, container)
        .onChange(of: layoutVM.activeViewContainerIcon) { _, _ in
            updateViewContainerTitle(container: container)
        }
        .background {
            WindowAccessor { window in
                RootContainer.shared.windowManagerVM.associateWindow(window, with: container.id)
                window.configureForLumiMainChrome()
                window.title = container.title
            }
        }
    }

    /// 主内容区域：活动栏 + Rail + 面板 + 右侧栏（只要有插件提供右侧视图就显示）
    @ViewBuilder
    private var mainContent: some View {
        Group {
            let activeIcon = layoutVM.activeViewContainerIcon
            let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
            let pluginContext = PluginContext(
                activeIcon: activeIcon,
                isEditorVisible: layoutVM.editorVisible,
                supportsAIChat: activeContainer?.supportsAIChat ?? false,
                showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
                showsRail: activeContainer?.showsRail ?? false,
                windowId: windowContainer?.id,
                messageRenderer: renderMessage
            )
            let rawSidebarSections = pluginProvider.getSidebarSections(context: pluginContext)
            let sidebarSections = layoutVM.rightSidebarVisible ? rawSidebarSections : []
            let hasRailTabs = pluginProvider.hasRailTabs(context: pluginContext)
            let showRail = hasRailTabs && layoutVM.railVisible
            let showEditor = layoutVM.editorVisible

            let layoutSignature = Self.layoutSignature(hasRail: showRail, hasSidebar: !sidebarSections.isEmpty)
            let autosaveName = "Unified_MainSplit_\(layoutSignature)"

            if !sidebarSections.isEmpty && showRail {
                HSplitView {
                    ActivityBar()
                        .frame(maxHeight: .infinity)
                    RailView()
                        .frame(maxHeight: .infinity)
                        .background(SplitViewWidthPersistence(
                            storageKey: "Layout.Main.Rail",
                            columnIndex: 1
                        ))
                    if showEditor {
                        PanelView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    RightSidebarContainerView(sections: sidebarSections)
                        .frame(maxHeight: .infinity)
                        .background(SplitViewWidthPersistence(
                            storageKey: "Layout.Main.RightSidebar",
                            columnIndex: 3
                        ))
                }
                .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
            } else if !sidebarSections.isEmpty {
                HSplitView {
                    ActivityBar()
                        .frame(maxHeight: .infinity)
                    if showEditor {
                        PanelView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    RightSidebarContainerView(sections: sidebarSections)
                        .frame(maxHeight: .infinity)
                        .background(SplitViewWidthPersistence(
                            storageKey: "Layout.Main.RightSidebar",
                            columnIndex: 2
                        ))
                }
                .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
            } else if showRail {
                HSplitView {
                    ActivityBar()
                        .frame(maxHeight: .infinity)
                    RailView()
                        .frame(maxHeight: .infinity)
                        .background(SplitViewWidthPersistence(
                            storageKey: "Layout.Main.Rail",
                            columnIndex: 1
                        ))
                    if showEditor {
                        PanelView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
            } else {
                HSplitView {
                    ActivityBar()
                        .frame(maxHeight: .infinity)
                    if showEditor {
                        PanelView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyContentGuideView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
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

    private func renderMessage(_ message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView? {
        guard let renderer = messageRendererVM.findRenderer(for: message) else {
            return nil
        }
        return renderer.render(message: message, showRawMessage: showRawMessage)
    }
}

// MARK: - Content View Body

struct ContentViewBody<Content: View>: View {
    @LumiMotionPreferenceReader private var motionPreference
    @State private var systemColorScheme: ColorScheme = SystemAppearanceResolver.effectiveColorScheme

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

    private var preferredColorScheme: ColorScheme? {
        if themeVM.activeChromeTheme.followsSystemAppearance {
            // 显式跟随系统外观，避免从固定深色主题切换后仍继承 .preferredColorScheme(.dark)。
            return systemColorScheme
        }
        return themeVM.activeChromeTheme.isDarkTheme ? .dark : .light
    }

    var body: some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .onOpenSettings(perform: openSettings)
            .onOpenPluginSettings(perform: openPluginSettings)
            .ignoresSafeArea()
            .background {
                GeometryReader { proxy in
                    themeVM.activeChromeTheme.makeGlobalBackground(proxy: proxy)
                }
            }
            .animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference), value: themeVM.currentThemeId)
            .onAppear {
                refreshSystemColorScheme()
                onAppear()
            }
            .onChange(of: themeVM.currentThemeId) { _, _ in
                refreshSystemColorScheme()
            }
            .onReceive(NSApp.publisher(for: \.effectiveAppearance)) { _ in
                guard themeVM.activeChromeTheme.followsSystemAppearance else { return }
                refreshSystemColorScheme()
            }
            .onChange(of: columnVisibility) { _, _ in
                onChangeColumnVisibility()
            }
            .overlay {
                pluginProvider.getRootViewWrapper(content: { EmptyView() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .overlay {
                ToolPermissionOverlay()
            }
    }

    private func refreshSystemColorScheme() {
        let resolved = SystemAppearanceResolver.effectiveColorScheme
        if systemColorScheme != resolved {
            systemColorScheme = resolved
        }
        if themeVM.activeChromeTheme.followsSystemAppearance {
            themeVM.refreshAppearanceDependentChrome()
        }
    }
}

// MARK: - Event Handler

extension ContentView {
    func onAppear(container: WindowContainer) {
        // 注册窗口到 WindowManager
        RootContainer.shared.windowManagerVM.registerContainer(container)

        container.restorePersistedStateIfAvailable(
            allowProjectRestore: initialProjectPath?.isEmpty != false
        )
        container.configurePersistenceObserversIfNeeded()

        if let path = initialProjectPath, !path.isEmpty, !container.projectVM.isProjectSelected {
            let name = URL(fileURLWithPath: path).lastPathComponent
            container.projectVM.switchProject(
                to: Project(name: name, path: path, lastUsed: Date()),
                reason: "contentViewInitialProjectPath"
            )
        }

        // 应用默认配置
        if let defaultSidebarVisibility = defaultSidebarVisibility {
            container.sidebarVisibility = defaultSidebarVisibility
        }

        // 设置标题同步
        setupWindowTitleObserver(container: container)
    }

    private func setupWindowTitleObserver(container: WindowContainer) {
        container.$title
            .receive(on: DispatchQueue.main)
            .sink { newTitle in
                if let window = RootContainer.shared.windowManagerVM.window(for: container.id) {
                    window.title = newTitle
                }
            }
            .store(in: &container.cancellables)
    }

    func onChangeColumnVisibility(container: WindowContainer) {
        if container.columnVisibility == .detailOnly {
            container.sidebarVisibility = false
        } else {
            container.sidebarVisibility = true
        }
    }

    func openSettings() {
        openWindow(id: AppConfig.settingsWindowID)
    }

    func openPluginSettings() {
        openWindow(id: AppConfig.settingsWindowID)
    }

    /// 根据当前激活的图标查询插件标题，并通知容器更新窗口标题
    private func updateViewContainerTitle(container: WindowContainer) {
        guard let icon = layoutVM.activeViewContainerIcon else {
            container.setActiveViewContainerTitle(nil)
            return
        }
        let item = pluginProvider.getViewContainerItems().first { $0.icon == icon }
        container.setActiveViewContainerTitle(item?.title)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .withDebugBar()
}
