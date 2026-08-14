import Foundation
import KernelLumi
import SwiftUI
import WebServerKit

/// 本地 Web 服务插件。
///
/// 在内核中注册 `WebServerProviding` 实现(`LumiWebServer`),启动一个仅监听
/// 127.0.0.1 的 HTTP 服务,聚合所有插件通过 `webRoutes(kernel:)` 贡献的路由。
///
/// 默认启用(`optOut`),用户可在插件管理中关闭。启动失败(如端口被占用)
/// 不会中断 App,仅打印告警、服务保持不可用状态。
@MainActor
public final class WebServerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.web-server"
    public var name: String { "Web Server" }

    /// 基础服务段(100-199):必须在功能插件之前启动,确保 `kernel.webServer`
    /// 在 `PluginManager.registerWebRoutes` 收集路由时已就绪。
    public let order = 150
    public let policy: LumiPluginPolicy = .optOut
    public let stage: LumiPluginStage = .beta

    /// 默认监听端口。
    private let port = 7310
    private var server: LumiWebServer?

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        // onActivity 在网络线程触发;EventManager 是 @MainActor,需切到主线程发送事件,
        // 供 UI 层(toast)订阅 .lumiWebRequestReceived 做视觉反馈。
        let eventManager = kernel.eventManager
        let server = LumiWebServer(port: port) { activity in
            Task { @MainActor in
                eventManager.postWebRequestReceived(activity: activity)
            }
        }
        try kernel.registerWebServer(server)
        self.server = server
    }

    public func onReady(kernel: KernelLumi) async throws {
        try await startIfNeeded(kernel: kernel)
    }

    public func onEnable(kernel: KernelLumi) async throws {
        try await startIfNeeded(kernel: kernel)
    }

    public func onDisable(kernel: KernelLumi) async throws {
        await server?.stop()
    }

    private func startIfNeeded(kernel: KernelLumi) async throws {
        guard let server, !server.isRunning else { return }
        do {
            try await server.start()
            if let boundPort = server.boundPort {
                print("[WebServerPlugin] listening on http://127.0.0.1:\(boundPort)")
            }
        } catch {
            // 启动失败不致命:服务不可用,但 App 正常运行。
            print("[WebServerPlugin] failed to start on port \(port): \(error)")
        }
    }

    // MARK: - Contributions(本插件不贡献 UI / 工具 / 命令等)

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
