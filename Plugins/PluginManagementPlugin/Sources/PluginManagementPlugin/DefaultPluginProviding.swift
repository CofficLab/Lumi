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
        guard let kernel else { return }
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
                var viewContainer = ViewContainerItem(
                    id: container.id,
                    title: container.title,
                    systemImage: container.systemImage,
                    showsRail: container.showsRail,
                    showsPanelChrome: container.showsPanelChrome,
                    content: container.makeView
                )
                viewContainer.order = pluginOrder
                kernel.registerViewContainer(viewContainer)
            }

            // Register panel items from all plugins
            for item in plugin.panelHeaderItems(kernel: kernel) {
                kernel.registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: kernel) {
                var tabItem = PanelBottomTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                tabItem.order = pluginOrder
                kernel.registerPanelBottomTabItem(tabItem)
            }
            for item in plugin.panelRailTabItems(kernel: kernel) {
                var railItem = PanelRailTabItem(
                    id: item.id,
                    title: item.title,
                    systemImage: item.systemImage,
                    content: item.makeView
                )
                railItem.order = pluginOrder
                kernel.registerPanelRailTabItem(railItem)
            }

            // Register chat section items from all plugins
            for item in plugin.chatSectionItems(kernel: kernel) {
                var chatItem = ChatSectionItem(
                    id: item.id,
                    placement: item.placement,
                    fillsRemainingHeight: item.fillsRemainingHeight,
                    showsTrailingDivider: item.showsTrailingDivider,
                    content: item.makeView
                )
                chatItem.order = pluginOrder
                kernel.registerChatSectionItem(chatItem)
            }
            for item in plugin.chatSectionToolbarItems(kernel: kernel) {
                var toolbarItem = ChatSectionToolbarItem(
                    id: item.id,
                    placement: item.placement,
                    content: item.makeView
                )
                toolbarItem.order = pluginOrder
                kernel.registerChatSectionToolbarItem(toolbarItem)
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: kernel) {
                var barItem = ChatSectionToolbarBarItem(
                    id: item.id,
                    content: item.makeView
                )
                barItem.order = pluginOrder
                kernel.registerChatSectionToolbarBarItem(barItem)
            }
            for item in plugin.chatSectionHeaderItems(kernel: kernel) {
                var headerItem = ChatSectionHeaderItem(
                    id: item.id,
                    content: item.makeView
                )
                headerItem.order = pluginOrder
                kernel.registerChatSectionHeaderItem(headerItem)
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
                var logoItem: LogoItem
                if let makeOverlay = item.makeOverlay {
                    logoItem = LogoItem(
                        id: item.id,
                        makeView: item.makeView,
                        makeOverlay: makeOverlay
                    )
                } else {
                    logoItem = LogoItem(
                        id: item.id,
                        makeView: item.makeView
                    )
                }
                logoItem.order = pluginOrder
                kernel.registerLogoItem(logoItem)
            }

            // Register onboarding pages from all plugins
            for page in plugin.onboardingPages(kernel: kernel) {
                var pageItem = OnboardingPageItem(
                    id: page.id,
                    content: page.makeView
                )
                pageItem.order = pluginOrder
                kernel.registerOnboardingPage(pageItem)
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
            .sorted { $0.order < $1.order }
    }
}
