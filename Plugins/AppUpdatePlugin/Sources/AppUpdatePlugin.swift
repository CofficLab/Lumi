import LocalizationKit
import KernelLumi
import SwiftUI

/// App Update Plugin
///
/// Integrates the Sparkle framework to provide automatic update checking.
///
/// Responsibilities:
/// - Initialize `UpdateService.shared` on boot
/// - Trigger feed URL detection at app launch
/// - Contribute the "Check for Updates..." command with
///   `.appMenu` placement so it appears in the Lumi menu after "About"
/// - Provide the update service used by the General settings page
///
/// Other integration points use `NotificationCenter`:
/// - `MenuBarManagerPlugin` calls `UpdateService.shared.checkForUpdates()`
/// - `UpdateService` posts `.appUpdateReadyToInstall` → UI observes it
///
/// `policy = .alwaysOn`: update checking is core infrastructure.
@MainActor
public final class AppUpdatePlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-update"
    public var name: String {
        LumiPluginLocalization.string("App Update", bundle: .module)
    }
    public let order = 50
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        "Integrates Sparkle to check for and install app updates automatically."
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        // Eagerly touch the singleton so the notification observers are registered.
        // The actual Sparkle controller is lazily initialized on first use.
        let updateService = UpdateService.shared
        if let network = kernel.network {
            updateService.configure(network: network)
        }

        // Trigger feed URL detection at app launch.
        // This is a one-shot app-level action handled here in the plugin's
        // bootstrap lifecycle, keeping MacAgent decoupled from specific plugins.
        updateService.setupFeedURLIfNeeded()
    }

    public func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] {
        guard LumiRuntimeEnvironment.current.allowsAppUpdates else { return [] }
        // Contribute "Check for Updates..." to the app menu.
        // `.appMenu` placement ensures it appears in the Lumi menu after "About",
        // matching the conventional macOS location for this action.
        return [
            CommandMenuGroup(
                id: "\(id).commands",
                name: name,
                items: [
                    CommandItem(
                        id: "\(id).checkForUpdates",
                        title: LumiPluginLocalization.string("Check for Updates...", bundle: .module)
                    ) {
                        UpdateService.shared.checkForUpdates()
                    },
                ],
                placement: .appMenu
            ),
        ]
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(AppUpdateAboutView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
