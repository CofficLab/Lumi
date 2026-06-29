import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SwiftUI

@MainActor
final class PluginService: ObservableObject {
    let registeredPlugins: [any LumiPlugin.Type]
    @Published private(set) var enabledOverrides: [String: Bool]
    var onEnabledPluginsChanged: (() -> Void)?
    private let settingsStore: PluginSettingsStore

    init(settingsStore: PluginSettingsStore = PluginSettingsStore()) {
        self.settingsStore = settingsStore
        self.enabledOverrides = settingsStore.loadEnabledOverrides()
        self.registeredPlugins = LumiPluginRegistry.plugins
            .filter { $0.policy.shouldRegister }
            .sorted { $0.info.order < $1.info.order }
    }

    var plugins: [any LumiPlugin.Type] {
        registeredPlugins
    }

    var enabledPlugins: [any LumiPlugin.Type] {
        registeredPlugins.filter { isPluginEnabled($0) }
    }

    var editorExtensionPlugins: [any LumiEditorExtensionRegistering.Type] {
        EditorExtensionPluginRegistry.plugins
    }

    var enabledEditorExtensionPluginIDs: Set<String> {
        Set(
            editorExtensionPlugins
                .filter { isEditorExtensionEnabled($0) }
                .map { $0.extensionPluginInfo.id }
        )
    }

    func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        enabledPlugins.flatMap { plugin in
            plugin.titleToolbarItems(context: context)
        }
    }

    func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        enabledPlugins.flatMap { plugin in
            plugin.statusBarItems(context: context)
        }
    }

    func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        enabledPlugins.flatMap { plugin in
            plugin.viewContainers(context: context)
        }
    }

    func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        enabledPlugins
            .flatMap { plugin in
                plugin.menuBarContentItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        enabledPlugins
            .flatMap { plugin in
                plugin.menuBarPopupItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        enabledPlugins.flatMap { plugin in
            plugin.llmProviders(context: context)
        }
    }

    func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        enabledPlugins.flatMap { plugin in
            plugin.agentTools(context: context)
        }
    }

    func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        enabledPlugins.flatMap { plugin in
            plugin.sendMiddlewares(context: context)
        }
    }

    func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        enabledPlugins
            .flatMap { plugin in
                plugin.messageRenderers(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        enabledPlugins
            .flatMap { plugin in
                plugin.rootOverlays(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func onboardingPages(context: LumiPluginContext) -> [LumiPluginOnboardingPage] {
        enabledPlugins
            .flatMap { plugin in
                plugin.onboardingPages(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.chatSectionItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView {
        guard context.supportsChatSection else { return content }
        return enabledPlugins.reduce(content) { wrapped, plugin in
            plugin.chatSectionRootWrapper(context: context, content: wrapped)
        }
    }

    func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.chatSectionToolbarItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.chatSectionToolbarBarItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
        guard context.supportsChatSection else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.chatSectionHeaderItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        guard context.showsPanelChrome else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.panelHeaderItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        guard context.showsPanelChrome else { return [] }
        return enabledPlugins
            .flatMap { plugin in
                plugin.panelBottomTabItems(context: context)
            }
            .sorted { $0.order < $1.order }
    }

    func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        guard context.showsRail else { return [] }

        var items = enabledPlugins.flatMap { plugin in
            plugin.panelRailTabItems(context: context)
        }

        if context.showsPanelChrome,
           context.activeSectionID == LumiEditorPanelContainer.id,
           let editor = context.resolve(LumiEditorServicing.self) {
            let service = editor.editorService
            if let languageId = service.editing.detectedLanguage?.tsName,
               let registration = editor.extensionRegistry.railOutlineRegistration(for: languageId),
               !items.contains(where: { $0.id == registration.tabID }) {
                items.append(
                    LumiPanelRailTabItem(
                        id: registration.tabID,
                        order: 90,
                        title: registration.title,
                        systemImage: registration.systemImage,
                        content: {
                            registration.makeView()
                        }
                    )
                )
            }
        }

        return items.sorted { $0.order < $1.order }
    }

    func themeContributions() -> [LumiUIThemeContribution] {
        enabledPlugins.flatMap { plugin -> [LumiUIThemeContribution] in
            guard let provider = plugin as? any LumiUIThemeProviding.Type else {
                return []
            }

            return provider.themeContributions().map { contribution in
                LumiUIThemeContribution(
                    sortKey: ThemeSortKey(
                        pluginOrder: plugin.info.order,
                        themeId: contribution.id
                    ),
                    chromeTheme: contribution.chromeTheme,
                    editorThemeId: contribution.editorThemeId,
                    uiTheme: contribution.uiTheme,
                    attachments: contribution.attachments
                )
            }
        }
    }

    func eligibility(for plugin: any LumiPlugin.Type) -> LumiPluginEligibility {
        LumiPluginEligibility(
            policy: plugin.policy,
            userEnabled: userEnabledValue(for: plugin)
        )
    }

    func eligibility(for plugin: any LumiEditorExtensionRegistering.Type) -> LumiPluginEligibility {
        LumiPluginEligibility(
            policy: plugin.extensionPluginPolicy,
            userEnabled: userEnabledValue(for: plugin)
        )
    }

    func isPluginEnabled(_ plugin: any LumiPlugin.Type) -> Bool {
        eligibility(for: plugin).isEligible
    }

    func isEditorExtensionEnabled(_ plugin: any LumiEditorExtensionRegistering.Type) -> Bool {
        eligibility(for: plugin).isEligible
    }

    func setEditorExtensionPlugin(_ plugin: any LumiEditorExtensionRegistering.Type, enabled: Bool) {
        guard plugin.extensionPluginPolicy.isConfigurable else { return }

        enabledOverrides[plugin.extensionPluginInfo.id] = enabled
        settingsStore.saveEnabledOverrides(enabledOverrides)
        onEnabledPluginsChanged?()
        objectWillChange.send()
    }

    func setPlugin(_ plugin: any LumiPlugin.Type, enabled: Bool) {
        guard plugin.policy.isConfigurable else {
            return
        }

        enabledOverrides[plugin.info.id] = enabled
        settingsStore.saveEnabledOverrides(enabledOverrides)
        onEnabledPluginsChanged?()
        objectWillChange.send()
    }

    private func userEnabledValue(for plugin: any LumiPlugin.Type) -> Bool {
        enabledOverrides[plugin.info.id] ?? plugin.policy.enabledByDefault
    }

    private func userEnabledValue(for plugin: any LumiEditorExtensionRegistering.Type) -> Bool {
        enabledOverrides[plugin.extensionPluginInfo.id] ?? plugin.extensionPluginPolicy.enabledByDefault
    }

    /// Registers all plugin contributions with the appropriate registries.
    /// Should be called after plugins are loaded and enabled.
    @MainActor
    func registerPluginContributions(context: LumiPluginContext) {
        registerLogoContributions(context: context)
    }

    private func registerLogoContributions(context: LumiPluginContext) {
        let allItems = enabledPlugins.flatMap { plugin in
            plugin.logoItems(context: context)
        }
        LogoRegistry.shared.register(allItems)
    }
}

extension PluginService: LumiLLMProviderSettingsContributing {
    func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        enabledPlugins.flatMap { plugin in
            plugin.llmProviderSettingsViews(context: context)
        }
    }
}
