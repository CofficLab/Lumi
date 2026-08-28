import AppKit
import Combine
import AppUpdatePlugin
import KernelCore
import ProviderLogo
import ProviderMenuBar
import SwiftUI

/// AppKit status-item host retained from the legacy menu-bar implementation.
/// `MenuBarExtra` measures its label as a single compact menu-bar line and can
/// clip custom plugin views. A real `NSStatusItem` preserves their intrinsic
/// width and height, including the two-line network view and device charts.
@MainActor
final class LumiMenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var hostingView: LumiMenuBarHostingView<LumiMenuBarStatusView>?
    private var popover: NSPopover?

    func install(kernel: KernelCoreContainer) {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))

        let view = LumiMenuBarHostingView(
            rootView: LumiMenuBarStatusView(
                logo: kernel.resolveProvider((any LogoProviding).self),
                menuBar: kernel.resolveProvider((any MenuBarProviding).self)
            )
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            view.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 22)
        ])

        let popup = NSPopover()
        popup.behavior = .transient
        popup.animates = true
        popup.contentViewController = NSHostingController(
            rootView: LumiMenuBarPopoverHost(
                kernel: kernel,
                onShowMainWindow: { self.showMainWindow() },
                onCheckForUpdates: { UpdateService.shared.checkForUpdates() },
                onQuit: { NSApp.terminate(nil) }
            )
        )

        statusItem = item
        hostingView = view
        popover = popup
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        (NSApp.mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }))?
            .makeKeyAndOrderFront(nil)
    }
}

/// The legacy host deliberately lets mouse hit-testing fall through to the
/// status button, while still allowing the hosted SwiftUI view to draw freely.
final class LumiMenuBarHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct LumiMenuBarStatusView: View {
    let logo: (any LogoProviding)?
    let menuBar: (any MenuBarProviding)?
    @StateObject private var refreshModel: ProviderRefreshModel

    init(logo: (any LogoProviding)?, menuBar: (any MenuBarProviding)?) {
        self.logo = logo
        self.menuBar = menuBar
        _refreshModel = StateObject(wrappedValue: ProviderRefreshModel(providers: [logo, menuBar]))
    }

    var body: some View {
        let _ = refreshModel.revision
        HStack(spacing: 4) {
            if let logo,
               let item = logo.highestPriorityLogoItem {
                let scene: LogoScene = logo.isLogoHighlighted
                    ? .statusBarHighlighted
                    : .statusBar
                item.makeView(scene)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .frame(width: 20, height: 20)
            }

            if let menuBar {
                ForEach(menuBar.contentItems.sorted { $0.order < $1.order }) { item in
                    item.makeView()
                        .fixedSize(horizontal: true, vertical: true)
                        .help(item.title)
                }
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 20)
    }
}

struct LumiMenuBarPopoverHost: View {
    let menuBar: (any MenuBarProviding)?
    let onShowMainWindow: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void
    @StateObject private var refreshModel: ProviderRefreshModel

    init(
        kernel: KernelCoreContainer,
        onShowMainWindow: @escaping () -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        let resolvedMenuBar = kernel.resolveProvider((any MenuBarProviding).self)
        self.menuBar = resolvedMenuBar
        self.onShowMainWindow = onShowMainWindow
        self.onCheckForUpdates = onCheckForUpdates
        self.onQuit = onQuit
        _refreshModel = StateObject(wrappedValue: ProviderRefreshModel(providers: [resolvedMenuBar]))
    }

    var body: some View {
        let _ = refreshModel.revision
        LumiMenuBarPopover(
            items: menuBar?.popupItems ?? [],
            onShowMainWindow: onShowMainWindow,
            onCheckForUpdates: onCheckForUpdates,
            onQuit: onQuit
        )
    }
}

/// 将 Provider 自己的 `objectWillChange` 收敛到单个宿主 View。Kernel 不参与
/// 转发，因此菜单栏只会因 Logo/MenuBar Provider 的变化刷新。
@MainActor
final class ProviderRefreshModel: ObservableObject {
    @Published private(set) var revision = 0
    private var subscriptions: [AnyCancellable] = []

    init(providers: [Any?]) {
        for provider in providers.compactMap({ $0 }) {
            guard let observable = provider as? any ObservableObject,
                  let publisher = observable.objectWillChange as? ObservableObjectPublisher
            else { continue }
            publisher.sink { [weak self] _ in
                self?.revision &+= 1
            }
            .store(in: &subscriptions)
        }
    }
}

/// 状态栏 Popover 的宿主外壳。插件只贡献其业务区块；应用级操作由宿主统一
/// 提供，这与旧版 `MenuBarPopupView` 的职责划分一致。
struct LumiMenuBarPopover: View {
    let items: [MenuBarPopupItem]
    let onShowMainWindow: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var sortedItems: [MenuBarPopupItem] {
        items.sorted {
            if $0.order == $1.order { return $0.id < $1.id }
            return $0.order < $1.order
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !sortedItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(sortedItems) { item in
                        item.makeView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if item.id != sortedItems.last?.id {
                            Divider()
                        }
                    }
                }

                Divider()
            }

            actionSection
        }
        .frame(width: 280)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(systemColorScheme)
    }

    private var actionSection: some View {
        VStack(spacing: 0) {
            LumiMenuBarActionRow(
                title: localized("Open Lumi", chinese: "打开 Lumi"),
                icon: "macwindow",
                color: .accentColor,
                action: perform(onShowMainWindow)
            )
            Divider().padding(.leading, 36)
            LumiMenuBarActionRow(
                title: localized("Check for Updates", chinese: "检查更新"),
                icon: "arrow.down.circle",
                color: .accentColor,
                action: perform(onCheckForUpdates)
            )
            Divider().padding(.leading, 36)
            LumiMenuBarActionRow(
                title: localized("Quit Lumi", chinese: "退出 Lumi"),
                icon: "power",
                color: .red,
                action: perform(onQuit)
            )
        }
        .padding(.vertical, 8)
    }

    /// 与旧版资源表一致的宿主级本地化。菜单栏动作并不属于任一插件，不能再
    /// 硬编码英文；插件自己的文字仍继续由各自的 `.module` 资源提供。
    private func localized(_ english: String, chinese: String) -> String {
        Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? chinese : english
    }

    private var systemColorScheme: ColorScheme {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    private func perform(_ action: @escaping () -> Void) -> () -> Void {
        {
            dismiss()
            action()
        }
    }
}

/// 逐项复刻旧版 `MenuBarActionRow` 的密度、图标占位、悬停和文字层级。
/// 放在 App 宿主内是因为底部三个动作不是插件贡献，避免把 Lumi 产品文案
/// 误放入通用的 `ProviderMenuBar` 包。
struct LumiMenuBarActionRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isHovering ? Color.primary : color)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(isHovering ? Color.primary : Color.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.accentColor.opacity(0.16) : .clear)
        .onHover { isHovering = $0 }
    }
}
