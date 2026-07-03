import EditorService
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import SwiftUI
import os

@MainActor
final class PluginService: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.plugin")
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose = true

    let registeredPlugins: [any LumiPlugin.Type]
    @Published private(set) var enabledOverrides: [String: Bool]
    var onEnabledPluginsChanged: (() -> Void)?
    var onPluginLifecycleChange: ((any LumiPlugin.Type, Bool) -> Void)?
    private let settingsStore: PluginSettingsStore

    /// 跟踪插件的启用状态
    private var pluginEnabledStates: [String: Bool] = [:]

    init(settingsStore: PluginSettingsStore = PluginSettingsStore()) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 PluginService")
        }

        self.settingsStore = settingsStore
        self.enabledOverrides = settingsStore.loadEnabledOverrides()
        self.registeredPlugins = LumiPluginRegistry.plugins
            .filter { $0.policy.shouldRegister }
            .sorted { $0.info.order < $1.info.order }

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 \(self.registeredPlugins.count) 个插件")
        }
    }

    var plugins: [any LumiPlugin.Type] {
        registeredPlugins
    }

    var enabledPlugins: [any LumiPlugin.Type] {
        registeredPlugins.filter { isPluginEnabled($0) }
    }

    /// 获取支持编辑器扩展的插件列表
    var editorExtensionPlugins: [any LumiPlugin.Type] {
        registeredPlugins.filter { plugin in
            // 检查插件是否提供了编辑器扩展方法
            // 这里我们简化为检查 policy，因为提供编辑器扩展的插件应该有相应的 policy
            let hasExtension = plugin.policy == .alwaysOn || plugin.policy == .optIn || plugin.policy == .optOut
            return hasExtension
        }
    }

    var enabledEditorExtensionPluginIDs: Set<String> {
        Set(
            editorExtensionPlugins
                .filter { isPluginEnabled($0) }
                .map { $0.info.id }
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

    func onboardingPages(context: LumiPluginContext) -> [(order: Int, view: AnyView)] {
        enabledPlugins.flatMap { plugin in
            plugin.onboardingPages(context: context).map { view in
                (plugin.info.order, view)
            }
        }.sorted { $0.order < $1.order }
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

    func isPluginEnabled(_ plugin: any LumiPlugin.Type) -> Bool {
        eligibility(for: plugin).isEligible
    }

    func setPlugin(_ plugin: any LumiPlugin.Type, enabled: Bool) {
        guard plugin.policy.isConfigurable else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)插件 \(plugin.info.id) 不可配置")
            }

            return
        }

        let pluginId = plugin.info.id

        let previousState = pluginEnabledStates[pluginId] ?? isPluginEnabled(plugin)

        if Self.verbose {
            Self.logger.info("\(Self.t)设置插件 \(pluginId) -> \(enabled)")
        }

        enabledOverrides[pluginId] = enabled
        pluginEnabledStates[pluginId] = enabled
        settingsStore.saveEnabledOverrides(enabledOverrides)
        onEnabledPluginsChanged?()

        objectWillChange.send()

        // 如果状态实际发生变化，触发生命周期回调
        if previousState != enabled {
            onPluginLifecycleChange?(plugin, enabled)
        }
    }

    /// 获取插件的当前启用状态
    func getPluginEnabledState(_ plugin: any LumiPlugin.Type) -> Bool {
        pluginEnabledStates[plugin.info.id] ?? isPluginEnabled(plugin)
    }

    /// 初始化时记录所有插件的初始状态
    func initializePluginStates() {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化插件状态")
        }

        for plugin in registeredPlugins {
            pluginEnabledStates[plugin.info.id] = isPluginEnabled(plugin)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 插件状态初始化完成")
        }
    }

    private func userEnabledValue(for plugin: any LumiPlugin.Type) -> Bool {
        enabledOverrides[plugin.info.id] ?? plugin.policy.enabledByDefault
    }

    /// Registers all plugin contributions with the appropriate registries.
    /// Should be called after plugins are loaded and enabled.
    @MainActor
    func registerPluginContributions(context: LumiPluginContext) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注册插件贡献")
        }

        registerLogoContributions(context: context)
    }

    private func registerLogoContributions(context: LumiPluginContext) {
        let allItems = enabledPlugins.flatMap { plugin in
            plugin.logoItems(context: context)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)注册了 \(allItems.count) 个 Logo 贡献")
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
