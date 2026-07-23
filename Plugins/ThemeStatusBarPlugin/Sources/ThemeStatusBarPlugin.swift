import Foundation
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ThemeStatusBarPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme-status-bar"
    public let name = "Theme Status Bar"
    public let order = 22
    public let policy: LumiPluginPolicy = .alwaysOn

    private var themeService: ThemeManager?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        let themeServiceInstance = ThemeManager()
        kernel.registerThemeService(themeServiceInstance)
        self.themeService = themeServiceInstance

        if let pluginProviding = kernel.pluginManager as? PluginRegistry {
            themeServiceInstance.setPluginService(pluginProviding)
            themeServiceInstance.reloadThemes()
        }
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
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}

    // MARK: - Status Bar

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        guard let themeService = kernel.theme else {
            return [
                StatusBarItem(
                    id: "\(id).error",
                    title: "Theme",
                    systemImage: "exclamationmark.triangle.fill",
                    placement: .trailing,
                    statusBarView: { ThemeStatusBarErrorView(pluginName: self.name) }
                )
            ]
        }

        return [
            StatusBarItem(
                id: "\(id).switcher",
                title: "Theme",
                systemImage: "paintbrush",
                placement: .trailing,
                statusBarView: {
                    ThemeStatusBarView(themeService: themeService)
                }
            )
        ]
    }
}
