import LumiThemePack
import Combine
import Foundation
import KernelCore
import LumiUI
import PluginShowImage
import PluginToast
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderConversation
import ProviderNetwork
import ProviderRailView
import ProviderRootView
import PluginRootView
import ProviderSettingView
import ProviderTheme
import ProviderToast
import ProviderToolbar
import SwiftUI

/// 默认 `ViewFactory` 实现：使用内核已注册的 Provider 组装主视图与设置视图。
///
/// 视图组装逻辑（工具栏 / ActivityBar / Rail / 内容区注入、LumiUI 主题桥接）
/// 集中在此；`KernelFactory.makeMainView(kernel:)` 等入口
/// 委托本实现，宿主可通过自定义 `ViewFactory` 覆盖视图组装行为。
@MainActor
public struct DefaultViewFactory: ViewFactory {
    public init() {}

    /// 使用已装配的内核返回主视图（工具栏 + ActivityBar + Rail + 内容区）。
    ///
    /// - Important: 本方法是**纯读取**，可在 SwiftUI 视图构建期调用。区域贡献的
    ///   写入由 `LumiRegionWiring.wire(kernel:)` 在装配期完成；两者分离是为了避免
    ///   在 body 求值期间向 `@Published` 字段写入而触发
    ///   "Publishing changes from within view updates"。
    public func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text(pluginLocalizationMain.string("RootViewProviding not registered")))
        }

        // show_image 工具成功后只写 `ShowImageState`，真正把它渲染出来的
        // `ShowImageOverlay` 必须在这里挂到主视图树上，否则工具会宣告成功
        // 而用户看不到任何图片。
        let network = kernel.resolveProvider((any NetworkProviding).self)
        return themed(
            AnyView(
                ShowImageOverlay(network: network) {
                    rootView.makeRootView()
                }
            ),
            kernel: kernel
        )
    }

    /// 共享壳（LumiFactory）用的主视图组装：**纯读取**，可在 SwiftUI 视图初始化期调用。
    ///
    /// 与 `makeMainView(kernel:)` 的唯一区别是不再套 `ThemeHostingView`：共享壳的
    /// `HostThemeView` 已经负责明暗外观、窗口背景与 LumiUI 主题桥接，再包一层只会
    /// 造成双重 `preferredColorScheme` 与重复背景。
    ///
    /// `show_image` 工具的浮层与 ToastCenter 仍在这里挂载——两者都依赖 Lumi 的
    /// Provider 组合，共享壳不了解这些区域的存在。
    public static func shellMainView(kernel: KernelCoreContainer) -> AnyView {
        let content: AnyView
        if let rootView = kernel.resolveProvider((any RootViewProviding).self) {
            content = AnyView(rootView.makeRootView())
        } else {
            content = AnyView(Text(pluginLocalizationMain.string("RootViewProviding not registered")))
        }
        let network = kernel.resolveProvider((any NetworkProviding).self)
        let withImageOverlay = AnyView(ShowImageOverlay(network: network) { content })
        guard let center = kernel.resolveProvider((any ToastProviding).self) as? ToastCenter else {
            return withImageOverlay
        }
        return AnyView(ToastOverlay(content: withImageOverlay, center: center))
    }

    /// 使用已装配的内核返回设置视图（共享内核时使用）。
    ///
    /// 侧边栏顶部 Logo 由设置实现（如 `PluginSettingView`）作为内部行为自行渲染，
    /// 此处不再注入。主题桥接同样属于装配期职责（`LumiRegionWiring.wire`），
    /// 这里只做纯读取组装。
    public func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text(pluginLocalizationMain.string("SettingViewProviding not registered")))
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

        let chrome = LumiPaletteChromeTheme(theme: selected, colorScheme: colorScheme)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))

        // ThemeProviding is the source of truth in the new architecture, while
        // native views such as the project file tree listen for the shared
        // window-appearance sync notification to rebuild cached cells.
        ThemeWindowAppearanceSync.syncAllWindows()
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
/// 通过 `ThemeProviding` 主题事件感知主题切换（含其他窗口触发）。
@MainActor
private struct ThemeHostingView<Content: View>: View {
    let theme: any ThemeProviding
    let content: Content

    @StateObject private var themeObservation: ThemeObservationModel
    @State private var refreshTick = false

    init(theme: any ThemeProviding, content: Content) {
        self.theme = theme
        self.content = content
        _themeObservation = StateObject(wrappedValue: ThemeObservationModel(theme: theme))
    }

    var body: some View {
        let _ = refreshTick

        content
            .preferredColorScheme(preferredColorScheme)
            .background(backgroundColor)
            .onAppear { DefaultViewFactory.syncLumiTheme(theme) }
            .onReceive(themeObservation.$revision) { _ in
                // 主题切换后强制 body 重算，应用新的明暗与背景，
                // 并把新主题桥接到 LumiUI 主题体系（@LumiTheme / ChromeThemes）。
                refreshTick.toggle()
                DefaultViewFactory.syncLumiTheme(theme)
            }
            #if os(macOS)
            .onReceive(
                DistributedNotificationCenter.default().publisher(
                    for: Notification.Name("AppleInterfaceThemeChangedNotification")
                )
                .receive(on: RunLoop.main)
            ) { _ in
                guard theme.followsSystemAppearance else { return }
                refreshTick.toggle()
                DefaultViewFactory.syncLumiTheme(theme)
            }
            #endif
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

@MainActor
private final class ThemeObservationModel: ObservableObject {
    @Published private(set) var revision = 0
    private var handle: (any ThemeProvidingObserverHandle)?

    init(theme: any ThemeProviding) {
        handle = theme.addObserver { [weak self] _ in
            self?.revision += 1
        }
    }

}
