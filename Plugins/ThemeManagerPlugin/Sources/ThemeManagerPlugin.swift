import Foundation
import KernelLumi
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

    public func onBoot(kernel: KernelLumi) async throws {
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

    public func onReady(kernel: KernelLumi) async throws {
        themeService?.setKernel(kernel)
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        #if canImport(AppKit)
        // 主题切换器位于标题工具栏右上方。
        let themeAvailable = kernel.theme != nil
        return [
            LumiTitleToolbarItem(
                id: themeAvailable ? "\(id).switcher" : "\(id).error",
                title: LumiPluginLocalization.string("Theme", bundle: .module),
                placement: .trailing,
                order: 950
            ) {
                if themeAvailable {
                    ThemeToolbarView(kernel: kernel)
                } else {
                    ThemeToolbarErrorView(pluginName: self.name)
                }
            },
        ]
        #else
        // iOS 无标题工具栏：不贡献主题切换器。
        return []
        #endif
    }
    public func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] {
        guard let themeService else { return [] }
        return [themeService.commandMenuGroup()]
    }
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
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            ThemeLandingPage(displayName: LumiPluginLocalization.string("Theme Manager", bundle: .module), icon: "paintpalette")
        )
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}

    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] {
        // 主题切换器已移至标题工具栏右上方（见 titleToolbarItems）。
        return []
    }
}
