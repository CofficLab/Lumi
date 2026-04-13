import AppKit
import MagicKit
import SwiftUI

/// 主内容视图，管理应用的整体布局和导航结构
///
/// 支持多窗口模式，每个窗口有独立的 WindowState
struct ContentView: View, SuperLog {
    /// emoji 标识符
    nonisolated static let emoji = "📱"
    /// 是否启用详细日志输出
    nonisolated static let verbose: Bool = false
    @EnvironmentObject var app: GlobalVM
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var providerRegistry: LLMProviderRegistry

    /// 打开窗口的环境变量
    @Environment(\.openWindow) private var openWindow

    /// 当前配色方案（浅色/深色模式）
    @Environment(\.colorScheme) private var colorScheme

    /// 窗口级状态（每个窗口独立）
    @StateObject private var windowState: WindowState

    /// 默认选中的导航 ID
    var defaultNavigationId: String?

    /// 默认侧边栏可见性
    var defaultSidebarVisibility: Bool?

    /// 初始选中的会话 ID
    var initialConversationId: UUID?

    /// 初始项目路径
    var initialProjectPath: String?

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
                    VStack(spacing: 0) {
                        // 主内容区域：左侧栏 + 中间栏 + 右侧栏
                        Group {
                            if windowState.sidebarVisibility {
                                HSplitView {
                                    LeftSidebar(sidebarVisibility: $windowState.sidebarVisibility)
                                        .frame(minWidth: 210, idealWidth: 220, maxWidth: 400)
                                        .background(SplitViewWidthPersistenceConfigurator(storageKey: "Split.MainMode.SidebarFraction"))

                                    rightPrimaryContent
                                }
                                .background(SplitViewAutosaveConfigurator(autosaveName: "MainMode_SidebarSplit"))
                            } else {
                                rightPrimaryContent
                            }
                        }
                        .id("unifiedLeftSplitView")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        StatusBar()
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

    @ViewBuilder
    private var rightPrimaryContent: some View {
        // 中间 + 右侧区域（根据模式切换布局）
        Group {
            if app.selectedMode == .agent {
                // Agent 模式：三栏布局（中间 + 右侧）
                if providerRegistry.providerTypes.isEmpty {
                    AgentModeUnavailableGuideView()
                } else if pluginProvider.hasDetailViews() {
                    HSplitView {
                        MiddleColumn()
                            .background(SplitViewWidthPersistenceConfigurator(storageKey: "Split.AgentMode.DetailFraction"))
                        RightColumn()
                    }
                    .id("unifiedRightSplitView")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .background(SplitViewAutosaveConfigurator(autosaveName: "AgentMode_DetailRightSplit"))
                } else {
                    RightColumn()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // App 模式：仅使用中间栏，不占用右侧栏宽度
                MiddleColumn()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SplitView Autosave Helper

/// 为 macOS 的 `HSplitView` / `VSplitView` 配置 `autosaveName`，以持久化分栏宽度
private struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> AutosaveConfiguratorView {
        AutosaveConfiguratorView(autosaveName: autosaveName)
    }

    func updateNSView(_ nsView: AutosaveConfiguratorView, context: Context) {
        nsView.autosaveName = autosaveName
    }
}

/// 为 SplitView 增加显式宽度记忆（比例），用于下次主动恢复。
private struct SplitViewWidthPersistenceConfigurator: NSViewRepresentable {
    let storageKey: String

    func makeNSView(context: Context) -> SplitViewWidthPersistenceView {
        SplitViewWidthPersistenceView(storageKey: storageKey)
    }

    func updateNSView(_ nsView: SplitViewWidthPersistenceView, context: Context) {
        nsView.storageKey = storageKey
        nsView.attachIfNeeded()
    }
}

/// 在 viewDidMoveToWindow 中配置 NSSplitView 的 autosaveName，确保视图已在窗口层级中
private final class AutosaveConfiguratorView: NSView {
    var autosaveName: String {
        didSet { applyAutosaveIfNeeded() }
    }

    init(autosaveName: String) {
        self.autosaveName = autosaveName
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            applyAutosaveIfNeeded()
        }
    }

    private var hasApplied = false

    private func applyAutosaveIfNeeded() {
        guard !hasApplied, !autosaveName.isEmpty, let splitView = findSplitView() else { return }
        guard splitView.autosaveName != autosaveName else { return }

        splitView.identifier = NSUserInterfaceItemIdentifier(autosaveName)
        splitView.autosaveName = autosaveName
        hasApplied = true
    }

    /// 从当前视图向上查找，或从同层兄弟视图中查找 NSSplitView（SwiftUI .background 与主内容为兄弟关系）
    private func findSplitView() -> NSSplitView? {
        // 1. 向上遍历父视图链
        var current: NSView? = self
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            // 2. 检查兄弟视图中是否有 NSSplitView（包括其子视图）
            if let parent = node.superview {
                for sibling in parent.subviews where sibling !== node {
                    if let found = findSplitViewRecursive(in: sibling) {
                        return found
                    }
                }
            }
            current = node.superview
        }
        return nil
    }

    private func findSplitViewRecursive(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }
        if let sv = view as? NSSplitView { return sv }
        for subview in view.subviews {
            if let found = findSplitViewRecursive(in: subview) { return found }
        }
        return nil
    }
}

private final class SplitViewWidthPersistenceView: NSView {
    var storageKey: String
    private var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplySavedValue = false
    private var pendingRetryWorkItem: DispatchWorkItem?

    init(storageKey: String) {
        self.storageKey = storageKey
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard window != nil else { return }
        guard let splitView = findSplitView() else {
            scheduleRetryAttach()
            return
        }
        guard splitView !== observedSplitView else { return }

        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil
        observedSplitView = splitView
        didApplySavedValue = false

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }

        applySavedRatioIfNeeded()

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistCurrentRatio()
            }
        }
    }

    private func applySavedRatioIfNeeded() {
        guard !didApplySavedValue else { return }
        guard let splitView = observedSplitView else { return }
        guard splitView.arrangedSubviews.count >= 2 else { return }

        let savedRatio = UserDefaults.standard.double(forKey: storageKey)
        guard savedRatio > 0.0, savedRatio < 1.0 else {
            didApplySavedValue = true
            return
        }

        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else { return }
            guard splitView.arrangedSubviews.count >= 2 else { return }
            let total = splitView.bounds.width
            guard total > 0 else { return }

            let dividerThickness = splitView.dividerThickness
            let usableWidth = max(1, total - dividerThickness)
            let target = max(0, min(usableWidth, usableWidth * savedRatio))
            splitView.setPosition(target, ofDividerAt: 0)
            self.didApplySavedValue = true
        }
    }

    private func persistCurrentRatio() {
        guard let splitView = observedSplitView else { return }
        guard splitView.arrangedSubviews.count >= 2 else { return }

        let total = splitView.bounds.width
        guard total > 0 else { return }

        let usableWidth = total - splitView.dividerThickness
        guard usableWidth > 1 else { return }

        let firstWidth = splitView.arrangedSubviews[0].frame.width
        let ratio = firstWidth / usableWidth
        guard ratio > 0.0, ratio < 1.0 else { return }

        UserDefaults.standard.set(ratio, forKey: storageKey)
    }

    private func findSplitView() -> NSSplitView? {
        var current: NSView? = self
        while let node = current {
            if let sv = node as? NSSplitView { return sv }
            current = node.superview
        }
        return nil
    }

    private func scheduleRetryAttach() {
        pendingRetryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.attachIfNeeded()
        }
        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

}

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
                AppLogger.core.info("\(Self.t) Setting default navigation to: \(defaultNavigationId)")
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
            .sink { newTitle in
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

// MARK: - Clamped Extension

private extension Comparable {
    func clamped(min minValue: Self, max maxValue: Self) -> Self {
        Swift.min(Swift.max(self, minValue), maxValue)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
