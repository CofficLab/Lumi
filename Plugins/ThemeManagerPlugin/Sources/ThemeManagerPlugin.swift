import Foundation
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ThemeManagerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.theme-manager"
    public var name: String {
        LumiPluginLocalization.string("Theme Manager", bundle: .module)
    }

    public let order = 22
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    private var themeService: ThemeManager?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        // Resolve the plugin data directory through StorageService so the file
        // lands at <dataRoot>/ThemeManager/theme-selection.plist instead of the
        // legacy <Application Support>/LumiUI/theme-selection.plist. See
        // ThemeSelectionStore for the StoragePlugin convention.
        let pluginDataDirectory = kernel.storage?.pluginDataDirectory(for: ThemeSelectionStore.pluginName)
        let themeSelectionStore = ThemeSelectionStore(pluginDataDirectory: pluginDataDirectory)
        let themeServiceInstance = ThemeManager()
        themeServiceInstance.setThemeSelectionStore(themeSelectionStore)
        try kernel.registerThemeService(themeServiceInstance)
        self.themeService = themeServiceInstance

        themeServiceInstance.setPluginManager(kernel.pluginManager)
        themeServiceInstance.setEventManager(kernel.eventManager)
    }

    public func onReady(kernel: LumiKernel) async throws {
        themeService?.setKernel(kernel)
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func commandMenuGroups(kernel: LumiKernel) -> [CommandMenuGroup] {
        guard let themeService else { return [] }
        return [themeService.commandMenuGroup()]
    }
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
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        guard let themeService = kernel.theme else {
            return [
                StatusBarItem(
                    id: "\(id).error",
                    title: LumiPluginLocalization.string("Theme", bundle: .module),
                    systemImage: "exclamationmark.triangle.fill",
                    placement: .trailing,
                    statusBarView: { ThemeStatusBarErrorView(pluginName: self.name) }
                ),
            ]
        }

        return [
            StatusBarItem(
                id: "\(id).switcher",
                title: LumiPluginLocalization.string("Theme", bundle: .module),
                systemImage: "paintbrush",
                placement: .trailing,
                statusBarView: {
                    ThemeStatusBarView(kernel: kernel)
                }
            ),
        ]
    }
}
