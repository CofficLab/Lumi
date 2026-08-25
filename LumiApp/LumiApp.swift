import AppKit
import AppUpdatePlugin
import FactoryLumi
import KernelCore
import ProviderLogo
import ProviderMenuBar
import ProviderOnboarding
import ProviderToast
import PluginToast
import PluginToolbarSettings
import SwiftUI

/// 最小 App：验证「Factory 组装完整主视图 → App 展示窗口」链路。
///
/// App 只需要视图，视图组装（内核装配 + 工具栏/ActivityBar/Rail/内容注入）
/// 全部由 `KernelFactory.makeMainView()` 完成；设置窗口由
/// `KernelFactory.makeSettingsView()` 提供；工具栏设置按钮通过通知
/// （`lumiOpenSettings`）请求打开设置窗口；菜单栏由 `MenuBarProviding` 贡献。
@main
struct LumiMinimalApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: LumiAppDelegate
    /// 共享内核：主窗口、设置、菜单栏共用同一实例。
    @StateObject private var kernel: KernelCoreContainer
    @StateObject private var menuBarController: LumiMenuBarController

    /// 启动失败必须显式呈现，不能静默退化成一个没有 Provider 的空内核。
    private let bootstrapErrorDescription: String?

    /// 主视图在 `init` 中一次性装配并缓存，绝不能在 `body` 求值期间调用
    /// `makeMainView(kernel:)`：它会向 `DefaultRootViewProviding`
    /// （ObservableObject）的 `@Published` 属性注入视图，在视图更新期间发布
    /// `objectWillChange` 会触发 SwiftUI 的 "Publishing changes from within
    /// view updates is not allowed"，且发布经 Kernel 转发后会让 `body` 重新
    /// 求值 → 再次装配 → 无限循环刷屏。
    private let mainView: AnyView

    /// 设置视图同样在 `init` 中装配一次（避免每个窗口重复装配内核贡献）。
    private let settingsView: AnyView

    @Environment(\.openWindow) private var openWindow

    init() {
        do {
            // 先在 StateObject 的非 throwing autoclosure 外完成可能失败的装配。
            let assembledKernel = try KernelFactory.makeKernel()
            _kernel = StateObject(wrappedValue: assembledKernel)
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            bootstrapErrorDescription = nil
            mainView = (try? KernelFactory.makeMainView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(message: "Failed to assemble main view"))
            settingsView = (try? KernelFactory.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(message: "Failed to assemble settings view"))
            // Lumi 直营分发继续启用 Sparkle。触发单例初始化以安装更新通知观察者，
            // 并在启动时完成 feed URL 探测；菜单命令直接复用同一服务。
            AppUpdateBootstrap.start(kernel: assembledKernel)
        } catch {
            _kernel = StateObject(wrappedValue: KernelCoreContainer())
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            bootstrapErrorDescription = error.localizedDescription
            mainView = AnyView(BootstrapFailureView(message: error.localizedDescription))
            settingsView = AnyView(BootstrapFailureView(message: error.localizedDescription))
        }
    }

    var body: some Scene {
        WindowGroup("Lumi", id: "lumi.main") {
            // App 只做一件事：让 Factory 给一个视图。
            // 主窗口 / 设置窗口 / 菜单栏共享同一内核（kernel），
            // 主题切换后各窗口即时同步。
            // 注意：`.onReceive` 需应用到整个 `??` 表达式（否则会误绑到 fallback 分支）。
            ToastHost(
                content: OnboardingHost(content: mainView, kernel: kernel),
                kernel: kernel
            )
                // 与旧版 Lumi（WindowMain.configureForLumiMainChrome）一致：
                // 窗口内容延伸到标题栏区域（fullSizeContentView），
                // 工具栏从窗口顶部开始渲染，红绿灯悬浮在工具栏上。
                .background {
                    WindowAccessor { window in
                        window.configureForLumiMinimalChrome()
                    }
                }
                // 工具栏「设置」按钮点击后，通知 → 打开设置窗口
                .onReceive(NotificationCenter.default.publisher(for: .lumiOpenSettings)) { _ in
                    openWindow(id: "lumi.settings")
                }
                .onReceive(appDelegate.$pendingOpenPath.compactMap { $0 }) { path in
                    consumePendingOpenPath(path, kernel: kernel)
                }
                .onAppear {
                    menuBarController.install(kernel: kernel)
                    // Launch Services may deliver a file before WindowGroup has
                    // installed its Combine subscription. Consume the retained
                    // delegate value once the V2 window is actually ready.
                    if let path = appDelegate.pendingOpenPath {
                        consumePendingOpenPath(path, kernel: kernel)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        // Preserve the legacy `AppBootstrap.defaultWindowSize` so existing
        // workspace, rail, chat, and plugin layouts open at their familiar
        // usable dimensions instead of the temporary minimal-host size.
        .defaultSize(width: 1100, height: 760)
        .commands {
            AppCommands(kernel: kernel) {
                UpdateService.shared.checkForUpdates()
            }
        }

        Window("设置", id: "lumi.settings") {
            settingsView
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        // Preserve the legacy `AppBootstrap.defaultSettingsWindowSize`.
        .defaultSize(width: 780, height: 600)

    }

    /// 与旧版 `MenuBarManagerPlugin.showMainWindow()` 保持相同行为：从状态栏
    /// 弹窗唤回应用，并把可成为 key 的主窗口置前。
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func consumePendingOpenPath(_ path: String, kernel: KernelCoreContainer) {
        guard appDelegate.pendingOpenPath == path else { return }
        appDelegate.pendingOpenPath = nil
        Task { @MainActor in
            _ = await KernelFactory.openExternalPath(path, kernel: kernel)
        }
    }
}

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

        let view = LumiMenuBarHostingView(rootView: LumiMenuBarStatusView(kernel: kernel))
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
            rootView: LumiMenuBarPopoverHost(kernel: kernel) {
                self.showMainWindow()
            } onCheckForUpdates: {
                UpdateService.shared.checkForUpdates()
            } onQuit: {
                NSApp.terminate(nil)
            }
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

private struct LumiMenuBarStatusView: View {
    @ObservedObject var kernel: KernelCoreContainer

    var body: some View {
        HStack(spacing: 4) {
            if let logo = kernel.resolveProvider((any LogoProviding).self),
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

            if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
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

private struct LumiMenuBarPopoverHost: View {
    @ObservedObject var kernel: KernelCoreContainer
    let onShowMainWindow: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    var body: some View {
        LumiMenuBarPopover(
            items: kernel.resolveProvider((any MenuBarProviding).self)?.popupItems ?? [],
            onShowMainWindow: onShowMainWindow,
            onCheckForUpdates: onCheckForUpdates,
            onQuit: onQuit
        )
    }
}

private struct BootstrapFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "LumiMinimal 启动失败",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .textSelection(.enabled)
        .padding(24)
    }
}

/// 挂载 V2 ToastCenter，使插件和服务发出的提示真正呈现在主窗口上。
private struct ToastHost<Content: View>: View {
    let content: Content
    @ObservedObject var kernel: KernelCoreContainer

    var body: some View {
        if let center = kernel.resolveProvider((any ToastProviding).self) as? ToastCenter {
            ToastOverlay(content: content, center: center)
        } else {
            content
        }
    }
}

/// V2 first-run onboarding presenter. Pages are registered by plugins through
/// `OnboardingProviding`; this host owns persisted completion and replay.
private struct OnboardingHost<Content: View>: View {
    let content: Content
    @ObservedObject var kernel: KernelCoreContainer
    @AppStorage("com.coffic.lumi.onboarding.completed") private var completed = false
    @State private var isPresented = false
    @State private var pageIndex = 0

    private var pages: [OnboardingPageItem] {
        kernel.resolveProvider((any OnboardingProviding).self)?.allPages ?? []
    }

    var body: some View {
        content
            .onAppear {
                guard !completed, !pages.isEmpty else { return }
                isPresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Onboarding.Show"))) { notification in
                if notification.userInfo?["reset"] as? Bool == true { completed = false }
                pageIndex = 0
                isPresented = !pages.isEmpty
            }
            .sheet(isPresented: $isPresented) {
                OnboardingSheet(
                    pages: pages,
                    index: $pageIndex,
                    finish: {
                        completed = true
                        isPresented = false
                    }
                )
                .interactiveDismissDisabled()
            }
    }
}

private struct OnboardingSheet: View {
    let pages: [OnboardingPageItem]
    @Binding var index: Int
    let finish: () -> Void

    var body: some View {
        let safeIndex = min(max(index, 0), max(pages.count - 1, 0))
        VStack(spacing: 0) {
            HStack {
                Label("Getting started", systemImage: "graduationcap.fill")
                    .font(.headline)
                Spacer()
                Text("\(safeIndex + 1) of \(pages.count)").foregroundStyle(.secondary)
                Button("Skip") { finish() }.buttonStyle(.borderless)
            }
            .padding(20)
            Divider()
            if pages.indices.contains(safeIndex) {
                ScrollView { pages[safeIndex].makeView().padding(28) }
            }
            Divider()
            HStack {
                Button("Back") { index = max(0, safeIndex - 1) }
                    .disabled(safeIndex == 0)
                Spacer()
                Button(safeIndex == pages.count - 1 ? "Finish" : "Continue") {
                    if safeIndex == pages.count - 1 { finish() }
                    else { index = safeIndex + 1 }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 640, height: 550)
    }
}

/// 菜单栏图标：优先展示最高优先级插件贡献的 Logo，回退到默认 SF Symbol。
///
/// 观察共享内核：LogoProvider 注册时默认转发 `objectWillChange`，
/// 因此 Logo 项增删或高亮状态变化时图标会自动刷新。
private struct LumiMenuBarLabel: View {
    @ObservedObject var kernel: KernelCoreContainer

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let logo = kernel.resolveProvider((any LogoProviding).self),
                   let item = logo.highestPriorityLogoItem {
                    let scene: LogoScene = logo.isLogoHighlighted
                        ? .statusBarHighlighted
                        : .statusBar
                    item.makeView(scene)
                } else {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                }
            }
            .frame(width: 20, height: 20)

            // 此处必须进入 label，而不是只存在于 Popover：旧版状态栏会并列
            // 显示所有 `menuBarContentItems`（例如网速、CPU/内存概览）。
            if let menuBar = kernel.resolveProvider((any MenuBarProviding).self) {
                // Render each contribution at the host boundary, matching the
                // legacy NSStatusItem implementation. Wrapping all contributions
                // in one AnyView makes MenuBarExtra measure the group as a single
                // line and can drop the device metrics or the second network row.
                ForEach(menuBar.contentItems.sorted { $0.order < $1.order }) { item in
                    item.makeView()
                        .fixedSize(horizontal: true, vertical: true)
                        .help(item.title)
                }
            }
        }
        .padding(.horizontal, 2)
        .fixedSize(horizontal: true, vertical: true)
    }
}

/// 状态栏 Popover 的宿主外壳。插件只贡献其业务区块；应用级操作由宿主统一
/// 提供，这与旧版 `MenuBarPopupView` 的职责划分一致。
private struct LumiMenuBarPopover: View {
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
private struct LumiMenuBarActionRow: View {
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

/// 配置窗口 chrome：与旧版 Lumi（`WindowMain.configureForLumiMainChrome`）一致，
/// 内容延伸到标题栏区域（fullSizeContentView），红绿灯悬浮在工具栏上，
/// 保证顶部工具栏从窗口最顶部开始渲染、尺寸与旧版完全一致。
private extension NSWindow {
    func configureForLumiMinimalChrome() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        toolbar = nil
        styleMask.insert(.fullSizeContentView)
    }
}

/// 解析宿主 NSWindow 并应用 chrome 配置的辅助视图。
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HostView(onResolve: onResolve)
        view.resolveWindowIfAttached()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? HostView)?.resolveWindowIfAttached()
    }

    private final class HostView: NSView {
        let onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindowIfAttached()
        }

        func resolveWindowIfAttached() {
            guard let window else { return }
            onResolve(window)
        }
    }
}
