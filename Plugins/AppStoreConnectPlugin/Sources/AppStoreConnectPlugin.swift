import Foundation
import os.log
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI

@MainActor
public final class AppStoreConnectPlugin: LumiPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.app-store-connect"
    public let name = "AppStoreConnect"
    public let order = 65
    public nonisolated static let emoji = "🚀"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.app-store-connect", category: "AppStoreConnectPlugin")
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        AppStoreConnectPlugin.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListAppStoreConnectAppsTool(),
            ListAppStoreConnectVersionsTool(),
            CreateAppStoreConnectVersionTool(),
            ListAppStoreConnectLocalizationsTool(),
            ListAppStoreConnectScreenshotSetsTool(),
            ListAppStoreConnectScreenshotsTool(),
            ListAppStoreConnectCiProductsTool(),
            ListAppStoreConnectCiWorkflowsTool(),
            ReadAppStoreConnectCiWorkflowTool(),
            ListAppStoreConnectCiBuildRunsTool(),
            UpdateAppStoreConnectLocalizationTool(),
            CreateAppStoreConnectScreenshotSetTool(),
            StartAppStoreConnectCiBuildRunTool(),
            SetAppStoreConnectCiWorkflowEnabledTool(),
            ListAppStoreConnectCoverArtTool(),
            ReadAppStoreConnectCoverArtTool(),
            CreateAppStoreConnectCoverArtTool(),
            UpdateAppStoreConnectCoverArtTool(),
            ExportAppStoreConnectCoverArtTool(),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
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
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { AnyView(AboutView()) }
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
