import Foundation
import KernelLumi
import LumiUI
import os.log
import SuperLogKit
import SwiftUI

@MainActor
public final class AppStoreConnectPlugin: LumiPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.app-store-connect"
    public var name: String {
        AppStoreConnectLocalization.string("AppStoreConnect", bundle: .module)
    }

    public let order = 65
    public nonisolated static let emoji = "🚀"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.app-store-connect", category: "AppStoreConnectPlugin")
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        AppStoreConnectPlugin.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
        AppStoreConnectToolSupport.configure(network: kernel.network)
        if let network = kernel.network {
            VM.shared.configure(network: network)
            await ScreenshotImageCache.shared.configure(network: network)
        }
    }

    public func onReady(kernel: KernelLumi) async throws {
        await configureNetwork(from: kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        AppStoreConnectToolSupport.configure(network: kernel.network)
        return [
            ListAppStoreConnectAppsTool(),
            ListAppStoreConnectVersionsTool(),
            ReadAppStoreConnectVersionTool(),
            CreateAppStoreConnectVersionTool(),
            ReleaseAppStoreConnectVersionTool(),
            ListAppStoreConnectBuildsTool(),
            AssignAppStoreConnectBuildTool(),
            SubmitAppStoreConnectVersionTool(),
            WithdrawAppStoreConnectSubmissionTool(),
            ListAppStoreConnectLocalizationsTool(),
            CreateAppStoreConnectLocalizationTool(),
            ReadAppStoreConnectLocalizationTool(),
            ListAppStoreConnectScreenshotSetsTool(),
            ListAppStoreConnectScreenshotsTool(),
            UploadAppStoreConnectScreenshotTool(),
            DeleteAppStoreConnectScreenshotTool(),
            ListAppStoreConnectCiProductsTool(),
            ListAppStoreConnectCiWorkflowsTool(),
            ReadAppStoreConnectCiWorkflowTool(),
            ListAppStoreConnectCiBuildRunsTool(),
            UpdateAppStoreConnectLocalizationTool(),
            CreateAppStoreConnectScreenshotSetTool(),
            StartAppStoreConnectCiBuildRunTool(),
            SetAppStoreConnectCiWorkflowEnabledTool(),
        ]
    }

    private func configureNetwork(from kernel: KernelLumi) async {
        AppStoreConnectToolSupport.configure(network: kernel.network)
        guard let network = kernel.network else { return }
        VM.shared.configure(network: network)
        await ScreenshotImageCache.shared.configure(network: network)
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                AppStoreConnectToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "app-store-connect.sidebar",
                title: name,
                systemImage: "app.badge.checkmark",
                visibility: .viewContainer(id: id)
            ) {
                AppStoreConnectRailView(viewModel: VM.shared)
            },
        ]
    }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "app.badge.checkmark",
                railVisibility: .alwaysVisible,
                chatVisibility: .visibleByDefault,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported,
            ) {
                MainView()
            },
        ]
    }

    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { AnyView(AboutView()) }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
