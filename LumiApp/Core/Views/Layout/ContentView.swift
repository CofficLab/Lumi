import AppKit
import Combine
import MagicKit
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 布局完全由各插件自行决定，核心只提供活动栏 + 面板内容区。
/// 不再有全局右侧栏，右侧栏由各插件在自己的面板视图内自行管理。
///
/// ## 多窗口状态同步
///
/// ContentView 负责同步 WindowState（窗口级）与全局 VM（应用级）的状态：
/// - 窗口创建时：从全局 VM 或 route 参数初始化 WindowState
/// - 窗口活跃时：WindowState 变更会同步回全局 VM
/// - 全局 VM 变更时：如果当前窗口是活跃窗口，会同步到 WindowState
struct ContentView: View, SuperLog {
    nonisolated static let emoji = "📱"
    nonisolated static let verbose: Bool = false

    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var themeVM: ThemeVM
    @EnvironmentObject var providerRegistry: LLMProviderRegistry
    @EnvironmentObject var layoutVM: LayoutVM
    @EnvironmentObject var conversationVM: ConversationVM
    @EnvironmentObject var projectVM: ProjectVM

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme

    /// 窗口级状态（每个窗口独立）
    @StateObject private var windowState: WindowState

    /// 用于取消订阅
    @State private var syncCancellables = Set<AnyCancellable>()

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
        .environment(\.windowState, windowState)
        .background {
            // 使用 WindowAccessor 可靠获取当前 SwiftUI view 所在的 NSWindow，
            // 避免 NSApplication.shared.keyWindow 在多窗口场景下指向其他窗口。
            WindowAccessor { window in
                WindowManager.shared.associateWindow(window, with: windowState.id)
                window.title = windowState.title
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

                // 根据分栏组合生成布局签名，避免不同分栏数共享 autosaveName 导致位置错乱
                let layoutSignature = Self.layoutSignature(hasRail: hasRail, hasSidebar: !sidebarSections.isEmpty)
                let autosaveName = "Unified_MainSplit_\(layoutSignature)"

                if !sidebarSections.isEmpty && hasRail {
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

                        // 右侧栏：聚合所有插件提供的 Section 视图，VStack 垂直堆叠
                        RightSidebarContainerView(sections: sidebarSections)
                            .background(SplitViewWidthPersistence(
                                storageKey: "Layout.Main.RightSidebar",
                                columnIndex: 3
                            ))
                    }
                    .background(SplitViewAutosaveConfigurator(autosaveName: autosaveName))
                } else if !sidebarSections.isEmpty {
                    // 3 栏: ActivityBar(固定) | Panel | RightSidebar
                    HSplitView {
                        // 图标栏（固定 48px）
                        ActivityBar()

                        // 面板内容区（可拖拽调整宽度，按插件 id 持久化）
                        PanelContentView().frame(maxWidth: .infinity)

                        // 右侧栏：聚合所有插件提供的 Section 视图，VStack 垂直堆叠
                        RightSidebarContainerView(sections: sidebarSections)
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
            // 主题切换时平滑过渡颜色变化
            .animation(.easeInOut(duration: 0.25), value: themeVM.currentThemeId)
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

        // 窗口关联和标题设置已由 WindowAccessor 在 .background 中可靠完成，
        // 此处不再使用 NSApplication.shared.keyWindow 避免多窗口误关联。

        // 应用默认配置
        if let defaultSidebarVisibility = defaultSidebarVisibility {
            windowState.sidebarVisibility = defaultSidebarVisibility
        }

        // 初始化窗口状态：从全局 VM 或 route 参数同步
        initializeWindowState()

        // 设置双向状态同步
        setupStateSync()

        // 设置标题同步
        setupWindowTitleObserver()
    }

    /// 初始化窗口状态
    ///
    /// 如果 route 提供了初始参数，使用 route 参数；
    /// 否则从全局 VM 获取当前状态（仅在第一个窗口时）。
    private func initializeWindowState() {
        // 如果 route 提供了初始会话或项目，已经在 WindowState init 中处理
        if initialConversationId != nil || initialProjectPath != nil {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🪟 窗口 \(windowState.id.uuidString.prefix(8)) 使用 route 初始参数")
            }
            return
        }

        // 否则，如果是第一个窗口，从全局 VM 同步当前状态
        let isFirstWindow = WindowManager.shared.windowStates.count <= 1
        if isFirstWindow {
            // 同步当前会话
            if let currentConversationId = conversationVM.selectedConversationId {
                windowState.selectedConversationId = currentConversationId
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)🪟 窗口 \(windowState.id.uuidString.prefix(8)) 从全局 VM 同步会话: \(currentConversationId.uuidString.prefix(8))")
                }
            }

            // 同步当前项目
            if let currentProject = projectVM.currentProject {
                windowState.projectPath = currentProject.path
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)🪟 窗口 \(windowState.id.uuidString.prefix(8)) 从全局 VM 同步项目: \(currentProject.name)")
                }
            }
        }
    }

    /// 设置双向状态同步
    ///
    /// - WindowState -> 全局 VM：当窗口活跃时，WindowState 变更同步到全局 VM
    /// - 全局 VM -> WindowState：当窗口活跃时，全局 VM 变更同步到 WindowState
    private func setupStateSync() {
        let windowId = windowState.id

        // MARK: - WindowState -> 全局 VM

        // 同步会话选择到 ConversationVM
        windowState.$selectedConversationId
            .receive(on: DispatchQueue.main)
            .sink { [weak windowState] newConversationId in
                guard let windowState = windowState else { return }
                // 只有活跃窗口才同步到全局 VM
                guard windowState.isActive else { return }

                // 避免循环同步
                if conversationVM.selectedConversationId != newConversationId {
                    conversationVM.setSelectedConversation(newConversationId)
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)🔄 窗口 \(windowId.uuidString.prefix(8)) -> 全局会话: \(newConversationId?.uuidString.prefix(8) ?? "nil")")
                    }
                }
            }
            .store(in: &syncCancellables)

        // 同步项目选择到 ProjectVM
        windowState.$projectPath
            .receive(on: DispatchQueue.main)
            .sink { [weak windowState] newPath in
                guard let windowState = windowState else { return }
                // 只有活跃窗口才同步到全局 VM
                guard windowState.isActive else { return }

                let currentPath = projectVM.currentProject?.path
                // 避免循环同步
                if currentPath != newPath {
                    if let path = newPath {
                        let projectName = URL(fileURLWithPath: path).lastPathComponent
                        let project = Project(name: projectName, path: path, lastUsed: Date())
                        projectVM.switchProject(to: project)
                    } else {
                        projectVM.clearProject()
                    }
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)🔄 窗口 \(windowId.uuidString.prefix(8)) -> 全局项目: \(newPath ?? "nil")")
                    }
                }
            }
            .store(in: &syncCancellables)

        // MARK: - 全局 VM -> WindowState

        // 监听全局会话变化，同步到活跃窗口
        conversationVM.$selectedConversationId
            .receive(on: DispatchQueue.main)
            .sink { [weak windowState] globalConversationId in
                guard let windowState = windowState else { return }
                // 只有活跃窗口才接收全局变更
                guard windowState.isActive else { return }

                // 避免循环同步
                if windowState.selectedConversationId != globalConversationId {
                    windowState.selectedConversationId = globalConversationId
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)🔄 全局会话 -> 窗口 \(windowId.uuidString.prefix(8)): \(globalConversationId?.uuidString.prefix(8) ?? "nil")")
                    }
                }
            }
            .store(in: &syncCancellables)

        // 监听全局项目变化，同步到活跃窗口
        projectVM.$currentProject
            .receive(on: DispatchQueue.main)
            .sink { [weak windowState] globalProject in
                guard let windowState = windowState else { return }
                // 只有活跃窗口才接收全局变更
                guard windowState.isActive else { return }

                let newPath = globalProject?.path
                // 避免循环同步
                if windowState.projectPath != newPath {
                    windowState.projectPath = newPath
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)🔄 全局项目 -> 窗口 \(windowId.uuidString.prefix(8)): \(newPath ?? "nil")")
                    }
                }
            }
            .store(in: &syncCancellables)

        // 监听窗口活跃状态变化
        windowState.$isActive
            .receive(on: DispatchQueue.main)
            .sink { [weak windowState] isActive in
                guard let windowState = windowState else { return }
                if isActive {
                    // 窗口变为活跃时，立即同步全局状态到窗口
                    if conversationVM.selectedConversationId != windowState.selectedConversationId {
                        windowState.selectedConversationId = conversationVM.selectedConversationId
                    }
                    if projectVM.currentProject?.path != windowState.projectPath {
                        windowState.projectPath = projectVM.currentProject?.path
                    }
                }
            }
            .store(in: &syncCancellables)
    }

    private func setupWindowTitleObserver() {
        let windowId = windowState.id
        windowState.$title
            .receive(on: DispatchQueue.main)
            .sink { newTitle in
                if let window = WindowManager.shared.window(for: windowId) {
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
