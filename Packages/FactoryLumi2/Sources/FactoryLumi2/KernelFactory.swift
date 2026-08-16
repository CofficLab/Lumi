import Foundation
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderContentView
import ProviderChatSection
import ProviderMessage
import ProviderAgentLoop
import ProviderLLM
import ProviderMessageSender
import ProviderConversation
import ProviderDocsView
import ProviderMenuBar
import ProviderLogo
import ProviderNetwork
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToast
import ProviderToolbar
import ProviderToolManager
import ProviderConversationInput
import ProviderMessageStreaming
import ProviderMessageRendering
import ProviderPromptSuggestion
import ProviderWorkspace
import ProviderOnboarding
import ProviderCommand
import ProviderIdleTime
import ProviderLegacyData
import ProviderPluginControl
import ProviderWebServer
import ProviderLLMManager
import SwiftUI

/// KernelFactory — 内核工厂。
///
/// 负责创建 KernelCore 内核，内部通过 `DefaultProviderFactory` 装配各 Provider
/// （Project / Toast / Network / Toolbar / RootView / ActivityBar / RailView /
/// SettingView），并通过 `start(plugins:)` 启动插件（如 SettingGeneralPlugin）
/// 注册各自的贡献。
@MainActor
public enum KernelFactory {

    /// 创建 KernelCore 内核，装配并注册全部默认 Provider：
    /// - `StorageProviding` → `DefaultStorageProvider`（Application Support 磁盘存储）
    /// - `ThemeProviding` → `DefaultThemeProviding`（内置主题注册表 + 选中持久化）
    /// - `ContentViewProviding` → `DefaultContentViewProviding`（当前内容视图）
    /// - `ConversationManaging` → `DefaultConversationManaging`（对话管理，内存实现）
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    /// - `RootViewProviding` → `DefaultRootViewProviding`（工具栏 + 内容区）
    /// - `ActivityBarProviding` → `DefaultActivityBarProviding`（竖直入口栏）
    /// - `RailViewProviding` → `DefaultRailViewProviding`（侧边栏标签 + 内容）
    /// - `SettingViewProviding` → `DefaultSettingViewProviding`（入口 + 详情）
    /// - `LLMProviderManagerProviding` → `DefaultLLMProviderManagerProviding`
    ///   （各 LLM 供应商注册表 + 选中路由，AgentLoop 经它发送）
    ///
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        try makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: additionalPlugins
        )
    }

    /// 异步插件目录的装配入口。
    ///
    /// 现有轻量插件可以继续使用同步 `makeKernel`；需要数据库迁移、进程启动、
    /// Language Server 或网络准备的插件应由宿主通过本入口启动，确保其
    /// `AsyncSuperPlugin` 生命周期不会被跳过。
    public static func makeKernelAsync(
        additionalPlugins: [any SuperPlugin] = []
    ) async throws -> KernelCoreContainer {
        try await makeKernelAsync(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: additionalPlugins
        )
    }

    public static func makeKernelAsync(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) async throws -> KernelCoreContainer {
        // 复用同一套 Provider composition；空目录先把内核推进 running，随后
        // `startAsync` 原子安装真实目录。后续宿主切换为异步启动时无需复制装配图。
        let kernel = try makeKernel(
            providerFactory: providerFactory,
            pluginFactory: EmptyPluginFactory(),
            additionalPlugins: []
        )
        try await kernel.startAsync(plugins: pluginFactory.makePlugins() + additionalPlugins)
        return kernel
    }

    /// 使用宿主提供的 Provider / Plugin 工厂装配内核。
    ///
    /// Provider 的创建与注册全部委托给 `providerFactory.registerProviders(into:)`；
    /// 本方法只负责创建容器、启动插件并完成插件启动后的视图绑定。
    public static func makeKernel(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try providerFactory.registerProviders(into: kernel)

        // 默认目录与宿主附加插件在同一个依赖图中统一校验、排序、原子启动。
        // 后续复刻插件只需由 App/专用 Factory 传入，不必继续修改内核工厂。
        try kernel.start(plugins: pluginFactory.makePlugins() + additionalPlugins)

        // header / toolbar 可见性绑定（复刻旧版 ChatView 语义：无选中会话时
        // 隐藏 header / toolbar，仅保留正文与输入区）。
        // 必须在插件启动完成后执行：此时 ConversationManaging 已是最终实例
        // （PluginConversationManager order=7 可能已替换默认内存实现）。
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            chat.bindConversationSelection(conversations)
        }

        return kernel
    }

    // MARK: - Main View Assembly

    /// 创建内核并组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// 视图组装逻辑集中在此：宿主只需要一个视图，无需关心内核如何把
    /// 各 Provider 的能力组合起来。返回的视图应用了当前选中主题
    /// （明暗外观 + 背景色）。
    ///
    /// - Returns: 已装配的根视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeMainView() throws -> AnyView {
        try makeMainView(kernel: makeKernel())
    }

    /// 使用已装配的内核组装主视图（共享内核时使用）。
    ///
    /// 宿主传入自己持有的 `KernelCoreContainer`，使主窗口 / 设置窗口 /
    /// 菜单栏共享同一内核与同一 `ThemeProviding`，主题切换即时同步。
    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text("RootViewProviding not registered"))
        }

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            rootView.setToolbarView(toolbar.makeToolbarView())
        }
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            rootView.setActivityBarView(activityBar.makeActivityBarView())
        }
        if let rail = kernel.resolveProvider((any RailViewProviding).self) {
            rootView.setRailView(rail.makeRailView())
        }
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            rootView.setContentView(contentView.makeContentView())
        }
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            rootView.setTrailingPane(RootTrailingPane(
                id: "com.coffic.lumi.workspace.chat",
                isVisible: chat.isVisible,
                content: chat.makeChatSectionView()
            ))
        }
        if let workspace = kernel.resolveProvider((any WorkspaceProviding).self) {
            rootView.setWorkspaceProvider(workspace)
        }
        return themed(rootView.makeRootView(), kernel: kernel)
    }

    // MARK: - Settings View Assembly

    /// 创建内核并返回设置视图。
    ///
    /// 设置视图的入口由已启动的插件（如 SettingGeneralPlugin）贡献；
    /// 宿主只需把返回的视图放进设置窗口（如 `Window("设置")`）即可。
    ///
    /// 复刻 LumiApp 设置体验：侧边栏顶部注入插件贡献的 Logo
    /// （`SettingsSidebarHeaderView`，`about` 场景，无贡献时回退主题色图标）。
    ///
    /// - Returns: 已装配的设置视图（`AnyView`）。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeSettingsView() throws -> AnyView {
        try makeSettingsView(kernel: makeKernel())
    }

    /// 使用已装配的内核返回设置视图（共享内核时使用）。
    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text("SettingViewProviding not registered"))
        }

        // 侧边栏顶部 Logo：取当前内核中最高优先级的插件 Logo（about 场景）。
        let logo = kernel.resolveProvider((any LogoProviding).self)
        if let defaultSettings = settings as? DefaultSettingViewProviding {
            defaultSettings.setSidebarHeader(AnyView(SettingsSidebarHeaderView(logo: logo)))
        }

        // 先把选中主题桥接到 LumiUI 主题体系，避免首帧渲染时 LumiUI 组件
        // （@LumiTheme / ChromeThemes）读到未配置的默认主题而闪烁。
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            syncLumiTheme(theme)
        }

        return themed(settings.makeSettingView(), kernel: kernel)
    }

    // MARK: - LumiUI Theme Bridging

    /// 把 `ThemeProviding` 选中的主题桥接到 LumiUI 主题体系（`@LumiTheme` /
    /// `ChromeThemes`），使 LumiUI 组件渲染出与旧版 Lumi 完全一致的颜色。
    ///
    /// 旧版设置窗口（`FactoryCore.SettingsView`）直接消费 `@LumiTheme`
    /// （= `ChromeToUIThemeAdapter(chrome: ActiveChromeTheme.current)`）；
    /// 新版统一走 `ThemeProviding` 的 palette。此处把 palette 适配回 chrome
    /// 主题并同步全局状态，让 `ProviderSettingView` 中的 LumiUI 组件
    /// （侧边栏、详情氛围渐变、窗口背景）拿到与旧版一致的配色。
    fileprivate static func syncLumiTheme(_ provider: any ThemeProviding) {
        guard let selected = provider.selectedTheme else { return }
        let chrome = PaletteChromeTheme(theme: selected)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))
    }

    // MARK: - Theme Application

    /// 用当前选中主题包装视图：明暗外观（`preferredColorScheme`）+ 背景色。
    ///
    /// `ThemeProviding` 未注册时原样返回（精简宿主 no-op）。
    private static func themed(_ view: AnyView, kernel: KernelCoreContainer) -> AnyView {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else {
            return view
        }
        return AnyView(ThemeHostingView(theme: theme, content: view))
    }
}

@MainActor
private struct EmptyPluginFactory: PluginFactory {
    func makePlugins() -> [any SuperPlugin] { [] }
}

/// 主题感知的视图包装：根据 `ThemeProviding` 的选中主题应用
/// 明暗外观与窗口背景色。
///
/// 通过 `onReceive(objectWillChange)` 感知主题切换（含其他窗口触发）。
@MainActor
private struct ThemeHostingView<Content: View>: View {
    let theme: any ThemeProviding
    let content: Content

    @State private var refreshTick = false

    var body: some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .background(backgroundColor)
            .onAppear { KernelFactory.syncLumiTheme(theme) }
            .onReceive(theme.objectWillChange) { _ in
                // 主题切换后强制 body 重算，应用新的明暗与背景，
                // 并把新主题桥接到 LumiUI 主题体系（@LumiTheme / ChromeThemes）。
                refreshTick.toggle()
                KernelFactory.syncLumiTheme(theme)
            }
    }

    /// 按主题外观类型解析窗口明暗；跟随系统时返回 `nil`（不强制）。
    private var preferredColorScheme: ColorScheme? {
        switch theme.selectedTheme?.appearanceKind ?? .system {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    /// 窗口背景色：主题的氛围中色（medium），无主题时回退系统窗口背景。
    private var backgroundColor: Color {
        theme.selectedTheme?.palette.atmosphere.medium ?? Color(nsColor: .windowBackgroundColor)
    }
}
