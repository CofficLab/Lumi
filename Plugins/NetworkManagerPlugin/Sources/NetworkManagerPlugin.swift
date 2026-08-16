import SwiftUI
import KernelLumi
import LumiUI
import os

/// 插件元信息
public struct PluginInfo {
    public let displayName: String
}

@MainActor
public final class NetworkManagerPlugin: LumiPlugin {
    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")
    public static let info = PluginInfo(displayName: "Network Monitor")
    private var httpExchangeStore: HTTPExchangeStore?

    public let id = "com.coffic.lumi.plugin.network-manager"
    public var name: String {
        LumiPluginLocalization.string("Network Monitor", bundle: .module)
    }
    public let order = 30
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        let exchangeStore = kernel.storage.map {
            HTTPExchangeStore(directory: $0.pluginDataDirectory(for: "NetworkManager"))
        }
        httpExchangeStore = exchangeStore
        NetworkService.shared.configureHTTPExchangeStore(exchangeStore)
        try kernel.registerService(NetworkProviding.self, NetworkProvider(exchangeStore: exchangeStore))
    }

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - Menu Bar

    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] {
        [
            MenuBarContentItem(id: "\(id).speed", order: order) {
                NetworkMenuBarContentView()
            },
        ]
    }

    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] {
        [
            MenuBarPopupItem(id: "\(id).popup", order: order) {
                NetworkMenuBarPopupView()
            },
        ]
    }

    // MARK: - About

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(NetworkManagerAboutView())
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }

    // MARK: - Agent Tools

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            ListHTTPExchangesTool(),
            GetHTTPSummaryTool(),
            GetHTTPExchangeDetailTool(),
            GetHTTPSlowRequestsTool(),
            GetHTTPFailedRequestsTool(),
            GetHTTPDomainLogTool(),
            DownloadFileTool(),
        ]
    }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] {
        [
            StatusBarItem(
                id: "\(id).export-progress",
                title: LumiPluginLocalization.string("HTTP Export Progress", bundle: .module),
                systemImage: "square.and.arrow.down",
                placement: .trailing,
                statusBarView: {
                    HTTPExportStatusBarView()
                }
            ),
        ]
    }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
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
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
