import Foundation
import LumiKernel
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

    public func onBoot(kernel: LumiKernel) async throws {
        AppStoreConnectPlugin.bootstrapFromLumiCoreIfNeeded(kernel: kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
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

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                Text(self.name)
                    .font(.system(size: 13, weight: .semibold))
            },
        ]
    }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
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
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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
