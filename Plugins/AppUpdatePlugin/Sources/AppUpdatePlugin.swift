import LocalizationKit
import LumiKernel
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

    public func onBoot(kernel: LumiKernel) async throws {
        // Eagerly touch the singleton so the notification observers are registered.
        // The actual Sparkle controller is lazily initialized on first use.
        let updateService = UpdateService.shared

        // Trigger feed URL detection at app launch.
        // This is a one-shot app-level action handled here in the plugin's
        // bootstrap lifecycle, keeping MacAgent decoupled from specific plugins.
        updateService.setupFeedURLIfNeeded()
    }

    public func commandMenuGroups(kernel: LumiKernel) -> [CommandMenuGroup] {
        // Contribute "Check for Updates..." to the app menu.
        // `.appMenu` placement ensures it appears in the Lumi menu after "About",
        // matching the conventional macOS location for this action.
        [
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

    public func onReady(kernel: LumiKernel) async throws {}

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] { [] }
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
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text(LumiPluginLocalization.string("App Update", bundle: .module))
                    .font(.headline)
                Text(pluginDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func editorPlugins(kernel: LumiKernel) -> [any EditorPlugin] { [] }
}
