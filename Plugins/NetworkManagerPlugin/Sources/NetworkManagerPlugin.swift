import SwiftUI
import LumiKernel
import LumiUI
import os

/// 插件元信息
public struct PluginInfo {
    public let displayName: String
}

@MainActor
public final class NetworkManagerPlugin: LumiPlugin {
    public nonisolated static let verbose = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")
    public static let info = PluginInfo(displayName: "Network Monitor")
    private var httpExchangeStore: HTTPExchangeStore?

    public let id = "com.coffic.lumi.plugin.network-manager"
    public let name = "Network Monitor"
    public let order = 30
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        let exchangeStore = kernel.storage.map {
            HTTPExchangeStore(directory: $0.pluginDataDirectory(for: "NetworkManager"))
        }
        httpExchangeStore = exchangeStore
        NetworkService.shared.configureHTTPExchangeStore(exchangeStore)
        try kernel.registerService(NetworkProviding.self, NetworkProvider(exchangeStore: exchangeStore))
    }

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - Menu Bar

    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] {
        [
            MenuBarContentItem(id: "\(id).speed", order: order) {
                NetworkMenuBarContentView()
            },
        ]
    }

    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] {
        [
            MenuBarPopupItem(id: "\(id).popup", order: order) {
                NetworkMenuBarPopupView()
            },
        ]
    }

    // MARK: - About

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(NetworkManagerAboutView())
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        guard let httpExchangeStore else { return [] }
        return [
            SettingsTabItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("HTTP Logs", bundle: .module),
                systemImage: "arrow.up.arrow.down.circle",
                order: order
            ) {
                HTTPExchangeSettingsView(store: httpExchangeStore)
            },
        ]
    }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
