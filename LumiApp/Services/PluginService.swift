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

    func isPluginEnabled(_ plugin: any LumiPlugin.Type) -> Bool {
        eligibility(for: plugin).isEligible
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
}
