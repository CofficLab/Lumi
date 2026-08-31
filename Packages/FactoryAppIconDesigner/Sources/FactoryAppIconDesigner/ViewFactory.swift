import Foundation
import KernelCore
import LumiUI
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderTheme
import ProviderToolbar
import SwiftUI

/// 默认 ViewFactory：组装 AppIconDesigner 的工具栏、导航、内容区和聊天侧栏。
@MainActor
public struct DefaultViewFactory: ViewFactory {
    public init() {}

    public func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            return AnyView(Text("RootViewProviding not registered"))
        }

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
            rootView.setRailViewVisible(rail.hasVisibleTabs)
            rootView.bindRailViewVisibility(to: rail.railVisibilityPublisher)
            rootView.bindRailViewWidth(to: rail.railWidthPublisher, onResize: rail.saveCurrentWidth)
        }
        if let contentView = kernel.resolveProvider((any ContentViewProviding).self) {
            rootView.setContentView(contentView.makeContentView())
        }
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            let trailingPane = RootTrailingPane(
                id: "com.coffic.lumi.workspace.chat",
                width: chat.chatSectionWidth,
                isVisible: chat.isVisible,
                content: chat.makeChatSectionView()
            )
            trailingPane.bindVisibility(to: chat)
            trailingPane.bindWidth(to: chat.chatSectionWidthPublisher, onResize: chat.saveCurrentWidth)
            rootView.setTrailingPane(trailingPane)
        }
        return themed(rootView.makeRootView(), kernel: kernel)
    }

    public func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            return AnyView(Text("SettingViewProviding not registered"))
        }

        if let theme = kernel.resolveProvider((any ThemeProviding).self) {
            Self.syncLumiTheme(theme)
        }
        return themed(settings.makeSettingView(), kernel: kernel)
    }

    static func syncLumiTheme(_ provider: any ThemeProviding) {
        guard let selected = provider.selectedTheme else { return }
        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark: colorScheme = .dark
        case .light: colorScheme = .light
        case .system: colorScheme = SystemAppearanceResolver.effectiveColorScheme
        }

        ResolvedSystemColorScheme.current = colorScheme
        let chrome = PaletteChromeTheme(theme: selected, colorScheme: colorScheme)
        ActiveChromeTheme.current = chrome
        LumiUIThemeStore.shared.setTheme(ChromeToUIThemeAdapter(chrome: chrome))
    }

    private func themed(_ view: AnyView, kernel: KernelCoreContainer) -> AnyView {
        guard let theme = kernel.resolveProvider((any ThemeProviding).self) else { return view }
        return AnyView(ThemeHostingView(theme: theme, content: view))
    }
}

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
        content
            .preferredColorScheme(preferredColorScheme)
            .background(backgroundColor)
            .onAppear { DefaultViewFactory.syncLumiTheme(theme) }
            .onReceive(themeObservation.$revision) { _ in
                refreshTick.toggle()
                DefaultViewFactory.syncLumiTheme(theme)
            }
    }

    private var preferredColorScheme: ColorScheme? {
        switch theme.selectedTheme?.appearanceKind ?? .system {
        case .dark: return .dark
        case .light: return .light
        case .system: return ResolvedSystemColorScheme.current
        }
    }

    private var backgroundColor: Color {
        guard let selected = theme.selectedTheme else { return Color(nsColor: .windowBackgroundColor) }
        let colorScheme: ColorScheme
        switch selected.appearanceKind {
        case .dark: colorScheme = .dark
        case .light: colorScheme = .light
        case .system: colorScheme = ResolvedSystemColorScheme.current
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
