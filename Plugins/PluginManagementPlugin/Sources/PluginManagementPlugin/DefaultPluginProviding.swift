import Foundation
import LumiKernel

// MARK: - Default Plugin Provider

/// 默认插件服务实现
///
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public final class DefaultPluginProviding: PluginProviding {
    public private(set) var allPlugins: [LumiPlugin] = []

    private var plugins: [String: LumiPlugin] = [:]
    private var pluginOrder: [String] = []

    /// Kernel 引用，用于插件启动和 UI 贡献注册
    weak var kernel: LumiKernel?

    public init() {}

    public func registerPlugin(_ plugin: LumiPlugin) throws {
        if plugins[plugin.id] == nil {
            pluginOrder.append(plugin.id)
        }
        plugins[plugin.id] = plugin
        updateSortedPlugins()
    }

    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    public func bootstrapPlugins() async throws {
        for plugin in allPlugins {
            try await plugin.boot(kernel: kernel)
        }
    }

    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        allPlugins.first(where: { $0 is T }) as? T
    }

    public func registerPluginUIContributions(in kernel: LumiKernel) {
        self.kernel = kernel

        for plugin in allPlugins {
            let pluginOrder = plugin.order

            // Register status bar items from all plugins
            for item in plugin.statusBarItems(kernel: kernel) {
                kernel.registerStatusBarItem(item)
            }

            // Register view containers from all plugins
            for container in plugin.viewContainers(kernel: kernel) {
                kernel.registerViewContainer(
                    ViewContainerItem(
                        id: container.id,
                        title: container.title,
                        systemImage: container.systemImage,
                        order: pluginOrder,
                        showsRail: container.showsRail,
                        showsPanelChrome: container.showsPanelChrome,
                        content: container.makeView
                    )
                )
            }

            // Register panel items from all plugins
            for item in plugin.panelHeaderItems(kernel: kernel) {
                kernel.registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: kernel) {
                kernel.registerPanelBottomTabItem(
                    PanelBottomTabItem(
                        id: item.id,
                        order: pluginOrder,
                        title: item.title,
                        systemImage: item.systemImage,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.panelRailTabItems(kernel: kernel) {
                kernel.registerPanelRailTabItem(
                    PanelRailTabItem(
                        id: item.id,
                        order: pluginOrder,
                        title: item.title,
                        systemImage: item.systemImage,
                        content: item.makeView
                    )
                )
            }

            // Register chat section items from all plugins
            for item in plugin.chatSectionItems(kernel: kernel) {
                kernel.registerChatSectionItem(
                    ChatSectionItem(
                        id: item.id,
                        order: pluginOrder,
                        placement: item.placement,
                        fillsRemainingHeight: item.fillsRemainingHeight,
                        showsTrailingDivider: item.showsTrailingDivider,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.chatSectionToolbarItems(kernel: kernel) {
                kernel.registerChatSectionToolbarItem(
                    ChatSectionToolbarItem(
                        id: item.id,
                        order: pluginOrder,
                        placement: item.placement,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: kernel) {
                kernel.registerChatSectionToolbarBarItem(
                    ChatSectionToolbarBarItem(
                        id: item.id,
                        order: pluginOrder,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.chatSectionHeaderItems(kernel: kernel) {
                kernel.registerChatSectionHeaderItem(
                    ChatSectionHeaderItem(
                        id: item.id,
                        order: pluginOrder,
                        content: item.makeView
                    )
                )
            }

            // Register settings items from all plugins
            for item in plugin.settingsTabItems(kernel: kernel) {
                kernel.registerSettingsTabItem(item)
            }
            for item in plugin.llmProviderSettingsItems(kernel: kernel) {
                kernel.registerLLMProviderSettingsItem(item)
            }

            // Register logo items from all plugins
            for item in plugin.logoItems(kernel: kernel) {
                if let makeOverlay = item.makeOverlay {
                    kernel.registerLogoItem(
                        LogoItem(
                            id: item.id,
                            order: pluginOrder,
                            makeView: item.makeView,
                            makeOverlay: makeOverlay
                        )
                    )
                } else {
                    kernel.registerLogoItem(
                        LogoItem(
                            id: item.id,
                            order: pluginOrder,
                            makeView: item.makeView
                        )
                    )
                }
            }

            // Register onboarding pages from all plugins
            for page in plugin.onboardingPages(kernel: kernel) {
                kernel.registerOnboardingPage(
                    OnboardingPageItem(
                        id: page.id,
                        order: pluginOrder,
                        content: page.makeView
                    )
                )
            }
        }

        // Sync layout active section with registered view containers.
        let containers = kernel.allViewContainers
        if let first = containers.first,
           let layoutService = kernel.layout,
           layoutService.state.activeSectionID.isEmpty {
            layoutService.updateLayout { state in
                state.activeSectionID = first.id
                state.activeSectionTitle = ""
            }
        }
    }

    private func updateSortedPlugins() {
        allPlugins = pluginOrder.compactMap { plugins[$0] }
    }
}
