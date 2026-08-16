import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
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
    /// - `StorageProviding` → `DefaultStorageProviding`（Application Support 磁盘存储）
    /// - `ThemeProviding` → `DefaultThemeProviding`（内置主题注册表 + 选中持久化）
    /// - `ContentViewProviding` → `DefaultContentViewProviding`（当前内容视图）
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    /// - `RootViewProviding` → `DefaultRootViewProviding`（工具栏 + 内容区）
    /// - `ActivityBarProviding` → `DefaultActivityBarProviding`（竖直入口栏）
    /// - `RailViewProviding` → `DefaultRailViewProviding`（侧边栏标签 + 内容）
    /// - `SettingViewProviding` → `DefaultSettingViewProviding`（入口 + 详情）
    ///
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        let factory = DefaultProviderFactory()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any StorageProviding).self, factory.makeStorageProvider())

        // 主题 Provider：选中主题持久化遵循 Storage 约定
        // （<数据根目录>/Plugins/ThemeManager/theme-selection.plist）。
        let themeProvider = factory.makeThemeProvider()
        if let storage = kernel.resolveProvider((any StorageProviding).self),
           let defaultTheme = themeProvider as? DefaultThemeProviding {
            defaultTheme.setStorageDirectory(storage.pluginDataDirectory(for: "ThemeManager"))
        }
        try kernel.registerProvider((any ThemeProviding).self, themeProvider)

        try kernel.registerProvider((any ContentViewProviding).self, factory.makeContentViewProvider())
        try kernel.registerProvider((any DocsViewProviding).self, factory.makeDocsViewProvider())
        try kernel.registerProvider((any MenuBarProviding).self, factory.makeMenuBarProvider())
        try kernel.registerProvider((any LogoProviding).self, factory.makeLogoProvider())
        try kernel.registerProvider((any ProjectProviding).self, factory.makeProjectProvider())
        try kernel.registerProvider((any ToastProviding).self, factory.makeToastProvider())
        try kernel.registerProvider((any NetworkProviding).self, factory.makeNetworkProvider())
        try kernel.registerProvider((any ToolbarProviding).self, factory.makeToolbarProvider())
        try kernel.registerProvider((any RootViewProviding).self, factory.makeRootViewProvider())
        try kernel.registerProvider((any ActivityBarProviding).self, factory.makeActivityBarProvider())
        try kernel.registerProvider((any RailViewProviding).self, factory.makeRailViewProvider())
        try kernel.registerProvider((any SettingViewProviding).self, factory.makeSettingViewProvider())
        // 启动插件（由 DefaultPluginFactory 产出）：注册各自的贡献。
        try kernel.start(plugins: DefaultPluginFactory().makePlugins())
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

        return themed(settings.makeSettingView(), kernel: kernel)
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
            .onReceive(theme.objectWillChange) { _ in
                // 主题切换后强制 body 重算，应用新的明暗与背景。
                refreshTick.toggle()
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
