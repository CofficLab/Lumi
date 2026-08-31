import AppKit
import AppUpdatePlugin
import FactoryLumi
import KernelCore
import PluginToast
import PluginToolbarSettings
import ProviderOnboarding
import ProviderSettingView
import ProviderToast
import SwiftUI

@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: LumiAppDelegate
    private let kernel: KernelCoreContainer
    @StateObject private var menuBarController: LumiMenuBarController
    private let toastCenter: ToastCenter?
    private let onboardingProvider: (any OnboardingProviding)?

    /// 启动失败必须显式呈现，不能静默退化成一个没有 Provider 的空内核。
    private let bootstrapErrorDescription: String?

    /// 主视图在 `init` 中一次性装配并缓存，绝不能在 `body` 求值期间调用
    /// `makeMainView(kernel:)`：它会向 `DefaultRootViewProviding`
    /// （ObservableObject）的 `@Published` 属性注入视图，在视图更新期间发布
    /// `objectWillChange` 会触发 SwiftUI 的 "Publishing changes from within
    /// view updates is not allowed"，因此不能在 `body` 求值期间反复装配。
    private let mainView: AnyView

    /// 设置视图同样在 `init` 中装配一次（避免每个窗口重复装配内核贡献）。
    private let settingsView: AnyView

    @Environment(\.openWindow) private var openWindow

    init() {
        do {
            // 先在属性初始化阶段完成可能失败的装配。
            let assembledKernel = try KernelFactory.makeKernel()
            kernel = assembledKernel
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            toastCenter = assembledKernel.resolveProvider((any ToastProviding).self) as? ToastCenter
            onboardingProvider = assembledKernel.resolveProvider((any OnboardingProviding).self)
            bootstrapErrorDescription = nil
            mainView = (try? KernelFactory.makeMainView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(message: "Failed to assemble main view"))
            settingsView = (try? KernelFactory.makeSettingsView(kernel: assembledKernel))
                ?? AnyView(BootstrapFailureView(message: "Failed to assemble settings view"))
            // Lumi 直营分发继续启用 Sparkle。触发单例初始化以安装更新通知观察者，
            // 并在启动时完成 feed URL 探测；菜单命令直接复用同一服务。
            AppUpdateBootstrap.start(kernel: assembledKernel)
        } catch {
            kernel = KernelCoreContainer()
            _menuBarController = StateObject(wrappedValue: LumiMenuBarController())
            toastCenter = nil
            onboardingProvider = nil
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
                content: OnboardingHost(content: mainView, provider: onboardingProvider),
                center: toastCenter
            )
            // 与旧版 Lumi（WindowMain.configureForLumiMainChrome）一致：
            // 窗口内容延伸到标题栏区域（fullSizeContentView），
            // 工具栏从窗口顶部开始渲染，红绿灯悬浮在工具栏上。
            .background {
                WindowAccessor { window in
                    window.configureForLumiMinimalChrome()
                }
            }
            // 工具栏「设置」或其他深链动作发出通知后，打开设置窗口。
            .onReceive(NotificationCenter.default.publisher(for: SettingViewNavigation.openSettingsNotification)) { notification in
                if let settings = kernel.resolveProvider((any SettingViewProviding).self),
                   let entryID = notification.userInfo?[SettingViewNavigation.entryIDUserInfoKey] as? String,
                   settings.entries.contains(where: { $0.id == entryID }) {
                    settings.selectEntry(id: entryID)
                }
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
        .defaultSize(width: 1000, height: 600)
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
    let center: ToastCenter?

    var body: some View {
        if let center {
            ToastOverlay(content: content, center: center)
        } else {
            content
        }
    }
}
