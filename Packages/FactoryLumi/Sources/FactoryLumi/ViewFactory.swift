import Foundation
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversation
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import ProviderToolbar
import ProviderWorkspace
import SwiftUI

/// 默认 `ViewFactory` 实现：使用内核已注册的 Provider 组装主视图与设置视图。
///
/// 视图组装逻辑（工具栏 / ActivityBar / Rail / 内容区注入、LumiUI 主题桥接）
/// 集中在此；`KernelFactory.makeMainView(kernel:)` 等入口
/// 委托本实现，宿主可通过自定义 `ViewFactory` 覆盖视图组装行为。
@MainActor
public struct DefaultViewFactory: ViewFactory {
    public init() {}

    /// 使用已装配的内核组装完整主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// 视图组装逻辑集中在此：宿主只需要一个视图，无需关心内核如何把
    /// 各 Provider 的能力组合起来。返回的视图应用了当前选中主题
    /// （明暗外观 + 背景色）。
    public func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text(LumiPluginLocalization.string("RootViewProviding not registered", bundle: .main)))
        }

        // ProviderTheme and LumiUI are separate layers. Resolve the selected
        // theme before constructing injected views so SwiftUI semantic colors
        // (.primary/.secondary) and AppKit controls see the same appearance
        // on their first render.
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            Self.syncLumiTheme(theme)
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

    /// 使用已装配的内核返回设置视图（共享内核时使用）。
    ///
    /// 侧边栏顶部 Logo 由设置实现（如 `PluginSettingView`）作为内部行为自行渲染，
    /// 此处不再注入。仅负责把选中主题桥接到 LumiUI 主题体系后返回设置视图。
    public func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text(LumiPluginLocalization.string("SettingViewProviding not registered", bundle: .main)))
        }

        // 先把选中主题桥接到 LumiUI 主题体系，避免首帧渲染时 LumiUI 组件
        // （@LumiTheme / ChromeThemes）读到未配置的默认主题而闪烁。
        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            Self.syncLumiTheme(theme)
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
    static func syncLumiTheme(_ provider: any ThemeProviding) {
        guard let selected = provider.selectedTheme else { return }
        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = SystemAppearanceResolver.effectiveColorScheme
        }

        // `LumiUITheme.preferredColorScheme` is consumed by the root view and
        // by AppKit appearance bridges. Keep its system value in sync with the
        // ProviderTheme selection instead of leaving the bootstrap `.light`
        // value in place.
        ResolvedSystemColorScheme.current = colorScheme

        let chrome = PaletteChromeTheme(theme: selected, colorScheme: colorScheme)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))
    }

    // MARK: - Theme Application

    /// 用当前选中主题包装视图：明暗外观（`preferredColorScheme`）+ 背景色。
    ///
    /// `ThemeProviding` 未注册时原样返回（精简宿主 no-op）。
    private func themed(_ view: AnyView, kernel: KernelCoreContainer) -> AnyView {
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
            .onAppear { DefaultViewFactory.syncLumiTheme(theme) }
            .onReceive(theme.objectWillChange) { _ in
                // 主题切换后强制 body 重算，应用新的明暗与背景，
                // 并把新主题桥接到 LumiUI 主题体系（@LumiTheme / ChromeThemes）。
                refreshTick.toggle()
                DefaultViewFactory.syncLumiTheme(theme)
            }
    }

    /// 按主题外观类型解析窗口明暗；跟随系统时使用已同步的系统明暗。
    private var preferredColorScheme: ColorScheme? {
        switch theme.selectedTheme?.appearanceKind ?? .system {
        case .dark: return .dark
        case .light: return .light
        case .system: return ResolvedSystemColorScheme.current
        }
    }

    /// 窗口背景色：主题的氛围中色（medium），无主题时回退系统窗口背景。
    private var backgroundColor: Color {
        guard let selected = theme.selectedTheme else {
            return Color(nsColor: .windowBackgroundColor)
        }

        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark:
            colorScheme = .dark
        case .light:
            colorScheme = .light
        case .system:
            colorScheme = ResolvedSystemColorScheme.current
        }
        return selected.palette.backgroundMedium.color(colorScheme: colorScheme)
    }
}
