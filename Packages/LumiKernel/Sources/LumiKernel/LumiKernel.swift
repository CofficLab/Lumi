import Combine
import Foundation
import LumiUI

/// Lumi lightweight core
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class LumiKernel: ObservableObject {
    // MARK: - Service Registry

    /// Service registry
    private var services: [ObjectIdentifier: Any] = [:]

    /// Service change subscriptions
    private var serviceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    // MARK: - Service Accessors (Protocol Types)

    /// Plugin management service
    public var plugin: (any PluginProviding)? {
        resolveService(PluginProviding.self)
    }

    /// Storage service
    public var storage: (any StorageProviding)? {
        resolveService(StorageProviding.self)
    }

    /// Project management service
    public var project: (any ProjectProviding)? {
        resolveService(ProjectProviding.self)
    }

    /// Layout service
    public var layout: (any LayoutProviding)? {
        resolveService(LayoutProviding.self)
    }

    /// View container service
    public var viewContainer: (any ViewContainerProviding)? {
        resolveService(ViewContainerProviding.self)
    }

    /// Command menu service
    public var command: (any CommandProviding)? {
        resolveService(CommandProviding.self)
    }

    /// Menu bar service
    public var menuBar: (any MenuBarProviding)? {
        resolveService(MenuBarProviding.self)
    }

    /// Title toolbar service
    public var titleToolbar: (any TitleToolbarProviding)? {
        resolveService(TitleToolbarProviding.self)
    }

    /// Send middleware service
    public var sendMiddleware: (any SendMiddlewareProviding)? {
        resolveService(SendMiddlewareProviding.self)
    }

    /// Chat service
    public var chat: (any ChatServiceProviding)? {
        resolveService(ChatServiceProviding.self)
    }

    /// Chat section service
    public var chatSection: (any ChatSectionProviding)? {
        resolveService(ChatSectionProviding.self)
    }

    /// Editor service
    public var editor: (any EditorServiceProviding)? {
        resolveService(EditorServiceProviding.self)
    }

    /// Agent tool service
    public var agentTool: (any AgentToolProviding)? {
        resolveService(AgentToolProviding.self)
    }

    /// Panel service
    public var panel: (any PanelProviding)? {
        resolveService(PanelProviding.self)
    }

    /// Status bar service
    public var statusBar: (any StatusBarProviding)? {
        resolveService(StatusBarProviding.self)
    }

    /// Settings service
    public var settings: (any SettingsProviding)? {
        resolveService(SettingsProviding.self)
    }

    /// Logo service
    public var logo: (any LogoProviding)? {
        resolveService(LogoProviding.self)
    }

    /// Theme service
    public var theme: (any ThemeProviding)? {
        resolveService(ThemeProviding.self)
    }

    /// Onboarding service
    public var onboarding: (any OnboardingProviding)? {
        resolveService(OnboardingProviding.self)
    }

    // MARK: - Initialization

    public init() {
        // Lightweight initialization, no concrete implementations created
    }

    // MARK: - Generic Service Registry

    /// Register service implementation
    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance

        // Forward objectWillChange from ObservableObject services
        subscribeToObjectWillChange(observable: instance, key: ObjectIdentifier(type))
    }

    /// Helper to subscribe to ObservableObject's objectWillChange
    private func subscribeToObjectWillChange<T>(observable: T, key: ObjectIdentifier) {
        guard let observableObject = observable as? any ObservableObject else { return }

        // Force cast to ObservableObjectPublisher which is the concrete type
        let publisher = observableObject.objectWillChange as! ObservableObjectPublisher
        serviceSubscriptions[key] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
            }
    }

    /// Resolve service implementation
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// Unregister service
    public func unregisterService<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        services.removeValue(forKey: key)
        serviceSubscriptions.removeValue(forKey: key)
    }

    // MARK: - Service Registration

    /// Register plugin management service
    public func registerPluginService(_ plugin: any PluginProviding) {
        registerService(PluginProviding.self, plugin)
    }

    /// Register storage service
    public func registerStorage(_ storage: any StorageProviding) {
        registerService(StorageProviding.self, storage)
    }

    /// Register project management service
    public func registerProject(_ project: any ProjectProviding) {
        registerService(ProjectProviding.self, project)
    }

    /// Register layout service
    public func registerLayout(_ layout: any LayoutProviding) {
        registerService(LayoutProviding.self, layout)
    }

    /// Register view container service
    public func registerViewContainerService(_ service: any ViewContainerProviding) {
        registerService(ViewContainerProviding.self, service)
    }

    /// Register command service
    public func registerCommandService(_ command: any CommandProviding) {
        registerService(CommandProviding.self, command)
    }

    /// Register menu bar service
    public func registerMenuBarService(_ menuBar: any MenuBarProviding) {
        registerService(MenuBarProviding.self, menuBar)
    }

    /// Register title toolbar service
    public func registerTitleToolbarService(_ titleToolbar: any TitleToolbarProviding) {
        registerService(TitleToolbarProviding.self, titleToolbar)
    }

    /// Register send middleware service
    public func registerSendMiddlewareService(_ sendMiddleware: any SendMiddlewareProviding) {
        registerService(SendMiddlewareProviding.self, sendMiddleware)
    }

    /// Register chat service
    public func registerChat(_ chat: any ChatServiceProviding) {
        registerService(ChatServiceProviding.self, chat)
    }

    /// Register chat section service
    public func registerChatSectionService(_ chatSection: any ChatSectionProviding) {
        registerService(ChatSectionProviding.self, chatSection)
    }

    /// Register editor service
    public func registerEditor(_ editor: any EditorServiceProviding) {
        registerService(EditorServiceProviding.self, editor)
    }

    /// Register agent tool service
    public func registerAgentToolService(_ agentTool: any AgentToolProviding) {
        registerService(AgentToolProviding.self, agentTool)
    }

    /// Register panel service
    public func registerPanelService(_ panel: any PanelProviding) {
        registerService(PanelProviding.self, panel)
    }

    /// Register status bar service
    public func registerStatusBarService(_ statusBar: any StatusBarProviding) {
        registerService(StatusBarProviding.self, statusBar)
    }

    /// Register settings service
    public func registerSettingsService(_ settings: any SettingsProviding) {
        registerService(SettingsProviding.self, settings)
    }

    /// Register logo service
    public func registerLogoService(_ logo: any LogoProviding) {
        registerService(LogoProviding.self, logo)
    }

    /// Register theme service
    public func registerThemeService(_ theme: any ThemeProviding) {
        registerService(ThemeProviding.self, theme)
    }

    /// Register onboarding service
    public func registerOnboardingService(_ onboarding: any OnboardingProviding) {
        registerService(OnboardingProviding.self, onboarding)
    }

    // MARK: - Convenience Accessors (Delegated)

    // MARK: - Plugin Convenience Accessors

    /// Register a plugin
    public func registerPlugin(_ plugin: LumiPlugin) throws {
        // 1. Call plugin's register method to register services
        try plugin.register(kernel: self)

        // 2. Register plugin instance to PluginProviding service (if available)
        // Note: PluginManagementPlugin registers PluginProviding service, so this will be nil for the first plugin
        try self.plugin?.registerPlugin(plugin)
    }

    /// Register multiple plugins
    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    /// Bootstrap all plugins
    public func bootstrapPlugins() async throws {
        try await plugin?.bootstrapPlugins()
    }

    /// Register UI contributions from all plugins
    ///
    /// This method should be called after all plugins have been registered and booted.
    /// It collects UI contributions from all plugins and registers them with the kernel.
    public func registerPluginUIContributions() {
        guard let pluginService = plugin else { return }

        for plugin in pluginService.allPlugins {
            let pluginOrder = plugin.order

            // Register status bar items from all plugins
            for item in plugin.statusBarItems(kernel: self) {
                registerStatusBarItem(item)
            }

            // Register view containers from all plugins
            for container in plugin.viewContainers(kernel: self) {
                registerViewContainer(
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
            for item in plugin.panelHeaderItems(kernel: self) {
                registerPanelHeaderItem(item)
            }
            for item in plugin.panelBottomTabItems(kernel: self) {
                registerPanelBottomTabItem(
                    PanelBottomTabItem(
                        id: item.id,
                        order: pluginOrder,
                        title: item.title,
                        systemImage: item.systemImage,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.panelRailTabItems(kernel: self) {
                registerPanelRailTabItem(
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
            for item in plugin.chatSectionItems(kernel: self) {
                registerChatSectionItem(
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
            for item in plugin.chatSectionToolbarItems(kernel: self) {
                registerChatSectionToolbarItem(
                    ChatSectionToolbarItem(
                        id: item.id,
                        order: pluginOrder,
                        placement: item.placement,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.chatSectionToolbarBarItems(kernel: self) {
                registerChatSectionToolbarBarItem(
                    ChatSectionToolbarBarItem(
                        id: item.id,
                        order: pluginOrder,
                        content: item.makeView
                    )
                )
            }
            for item in plugin.chatSectionHeaderItems(kernel: self) {
                registerChatSectionHeaderItem(
                    ChatSectionHeaderItem(
                        id: item.id,
                        order: pluginOrder,
                        content: item.makeView
                    )
                )
            }

            // Register settings items from all plugins
            for item in plugin.settingsTabItems(kernel: self) {
                registerSettingsTabItem(item)
            }
            for item in plugin.llmProviderSettingsItems(kernel: self) {
                registerLLMProviderSettingsItem(item)
            }

            // Register logo items from all plugins
            for item in plugin.logoItems(kernel: self) {
                if let makeOverlay = item.makeOverlay {
                    registerLogoItem(
                        LogoItem(
                            id: item.id,
                            order: pluginOrder,
                            makeView: item.makeView,
                            makeOverlay: makeOverlay
                        )
                    )
                } else {
                    registerLogoItem(
                        LogoItem(
                            id: item.id,
                            order: pluginOrder,
                            makeView: item.makeView
                        )
                    )
                }
            }

            // Register onboarding pages from all plugins
            for page in plugin.onboardingPages(kernel: self) {
                registerOnboardingPage(
                    OnboardingPageItem(
                        id: page.id,
                        order: pluginOrder,
                        content: page.makeView
                    )
                )
            }
        }

        // Sync layout active section with registered view containers.
        let containers = allViewContainers
        if let first = containers.first,
           let layoutService = layout,
           layoutService.state.activeSectionID.isEmpty {
            layoutService.updateLayout { state in
                state.activeSectionID = first.id
                state.activeSectionTitle = ""
            }
        }
    }

    /// Query plugin by type
    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        plugin?.plugin(ofType: type)
    }

    /// Query plugin by ID
    public func plugin(id: String) -> LumiPlugin? {
        plugin?.plugin(id: id)
    }

    /// All registered plugins
    public var allPlugins: [LumiPlugin] {
        plugin?.allPlugins ?? []
    }

    // MARK: - View Container Convenience Accessors

    /// All registered view containers (sorted by order)
    public var allViewContainers: [ViewContainerItem] {
        viewContainer?.allViewContainers ?? []
    }

    /// Register view container
    public func registerViewContainer(_ container: ViewContainerItem) {
        viewContainer?.register(container)
    }

    /// Unregister view container
    public func unregisterViewContainer(id: String) {
        viewContainer?.unregister(id: id)
    }

    // MARK: - Command Convenience Accessors

    /// Register command group
    public func registerCommandGroup(_ group: CommandMenuGroup) {
        command?.registerCommandGroup(group)
    }

    /// Register single command item (auto-grouped)
    public func registerCommand(menu: String, item: CommandItem) {
        command?.registerCommand(menu: menu, item: item)
    }

    /// All registered command groups
    public var allCommandGroups: [CommandMenuGroup] {
        command?.allCommandGroups ?? []
    }

    /// Query command group by name
    public func commandGroup(named name: String) -> CommandMenuGroup? {
        command?.commandGroup(named: name)
    }

    // MARK: - Menu Bar Convenience Accessors

    /// All registered menu bar contents (sorted by order)
    public var allMenuBarContents: [MenuBarContentItem] {
        menuBar?.allMenuBarContents ?? []
    }

    /// All registered menu bar popups (sorted by order)
    public var allMenuBarPopups: [MenuBarPopupItem] {
        menuBar?.allMenuBarPopups ?? []
    }

    /// Register menu bar content
    public func registerMenuBarContent(_ content: MenuBarContentItem) {
        menuBar?.registerMenuBarContent(content)
    }

    /// Unregister menu bar content
    public func unregisterMenuBarContent(id: String) {
        menuBar?.unregisterMenuBarContent(id: id)
    }

    /// Register menu bar popup
    public func registerMenuBarPopup(_ popup: MenuBarPopupItem) {
        menuBar?.registerMenuBarPopup(popup)
    }

    /// Unregister menu bar popup
    public func unregisterMenuBarPopup(id: String) {
        menuBar?.unregisterMenuBarPopup(id: id)
    }

    // MARK: - Title Toolbar Convenience Accessors

    /// All registered title toolbar items (sorted by order)
    public var allTitleToolbarItems: [TitleToolbarItem] {
        titleToolbar?.allTitleToolbarItems ?? []
    }

    /// Get title toolbar items by placement
    public func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem] {
        titleToolbar?.titleToolbarItems(placement: placement) ?? []
    }

    /// Register title toolbar item
    public func registerTitleToolbarItem(_ item: TitleToolbarItem) {
        titleToolbar?.registerTitleToolbarItem(item)
    }

    /// Unregister title toolbar item
    public func unregisterTitleToolbarItem(id: String) {
        titleToolbar?.unregisterTitleToolbarItem(id: id)
    }

    // MARK: - Send Middleware Convenience Accessors

    /// All registered send middlewares
    public var allSendMiddlewares: [any SendMiddleware] {
        sendMiddleware?.allSendMiddlewares ?? []
    }

    /// Register send middleware
    public func registerSendMiddleware(_ middleware: any SendMiddleware, id: String? = nil) {
        sendMiddleware?.registerSendMiddleware(middleware, id: id)
    }

    /// Unregister send middleware
    public func unregisterSendMiddleware(id: String) {
        sendMiddleware?.unregisterSendMiddleware(id: id)
    }

    // MARK: - Agent Tool Convenience Accessors

    /// All registered agent tools
    public var allAgentTools: [any LumiAgentTool] {
        agentTool?.allAgentTools ?? []
    }

    /// Register agent tool
    public func registerAgentTool(_ tool: any LumiAgentTool) {
        agentTool?.register(tool)
    }

    /// Unregister agent tool
    public func unregisterAgentTool(id: String) {
        agentTool?.unregister(id: id)
    }

    // MARK: - Editor Convenience Accessors

    /// 当前编辑器主题 ID
    public var currentEditorThemeId: String {
        editor?.currentThemeId ?? "xcode-dark"
    }

    /// 设置当前编辑器主题
    public func setCurrentEditorTheme(_ themeId: String) throws {
        guard let editorService = editor else {
            throw LumiKernelError.serviceNotAvailable(service: "Editor")
        }
        try editorService.setCurrentTheme(themeId)
    }

    /// 所有已注册的编辑器主题
    public var allEditorThemes: [EditorThemeInfo] {
        editor?.allEditorThemes ?? []
    }

    /// 注册编辑器主题
    public func registerEditorTheme(_ theme: EditorThemeInfo) {
        editor?.registerEditorTheme(theme)
    }

    /// 注销编辑器主题
    public func unregisterEditorTheme(themeId: String) {
        editor?.unregisterEditorTheme(themeId: themeId)
    }

    /// 根据主题 ID 获取语法调色板
    public func editorSyntaxPalette(for themeId: String) -> EditorSyntaxPalette? {
        editor?.editorSyntaxPalette(for: themeId)
    }

    // MARK: - Panel Convenience Accessors

    /// All registered panel header items
    public var allPanelHeaderItems: [PanelHeaderItem] {
        panel?.allPanelHeaderItems ?? []
    }

    /// All registered panel bottom tab items (sorted by order)
    public var allPanelBottomTabItems: [PanelBottomTabItem] {
        panel?.allPanelBottomTabItems ?? []
    }

    /// All registered panel rail tab items (sorted by order)
    public var allPanelRailTabItems: [PanelRailTabItem] {
        panel?.allPanelRailTabItems ?? []
    }

    /// Register panel header item
    public func registerPanelHeaderItem(_ item: PanelHeaderItem) {
        panel?.registerPanelHeaderItem(item)
    }

    /// Unregister panel header item
    public func unregisterPanelHeaderItem(id: String) {
        panel?.unregisterPanelHeaderItem(id: id)
    }

    /// Register panel bottom tab item
    public func registerPanelBottomTabItem(_ item: PanelBottomTabItem) {
        panel?.registerPanelBottomTabItem(item)
    }

    /// Unregister panel bottom tab item
    public func unregisterPanelBottomTabItem(id: String) {
        panel?.unregisterPanelBottomTabItem(id: id)
    }

    /// Register panel rail tab item
    public func registerPanelRailTabItem(_ item: PanelRailTabItem) {
        panel?.registerPanelRailTabItem(item)
    }

    /// Unregister panel rail tab item
    public func unregisterPanelRailTabItem(id: String) {
        panel?.unregisterPanelRailTabItem(id: id)
    }

    // MARK: - Chat Section Convenience Accessors

    /// All registered chat section items (sorted by order)
    public var allChatSectionItems: [ChatSectionItem] {
        chatSection?.allChatSectionItems ?? []
    }

    /// Get chat section items by placement
    public func chatSectionItems(placement: ChatSectionPlacement) -> [ChatSectionItem] {
        chatSection?.chatSectionItems(placement: placement) ?? []
    }

    /// All registered chat section toolbar items (sorted by order)
    public var allChatSectionToolbarItems: [ChatSectionToolbarItem] {
        chatSection?.allChatSectionToolbarItems ?? []
    }

    /// Get chat section toolbar items by placement
    public func chatSectionToolbarItems(placement: ChatSectionToolbarPlacement) -> [ChatSectionToolbarItem] {
        chatSection?.chatSectionToolbarItems(placement: placement) ?? []
    }

    /// All registered chat section toolbar bar items (sorted by order)
    public var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] {
        chatSection?.allChatSectionToolbarBarItems ?? []
    }

    /// All registered chat section header items (sorted by order)
    public var allChatSectionHeaderItems: [ChatSectionHeaderItem] {
        chatSection?.allChatSectionHeaderItems ?? []
    }

    /// Register chat section item
    public func registerChatSectionItem(_ item: ChatSectionItem) {
        chatSection?.registerChatSectionItem(item)
    }

    /// Unregister chat section item
    public func unregisterChatSectionItem(id: String) {
        chatSection?.unregisterChatSectionItem(id: id)
    }

    /// Register chat section toolbar item
    public func registerChatSectionToolbarItem(_ item: ChatSectionToolbarItem) {
        chatSection?.registerChatSectionToolbarItem(item)
    }

    /// Unregister chat section toolbar item
    public func unregisterChatSectionToolbarItem(id: String) {
        chatSection?.unregisterChatSectionToolbarItem(id: id)
    }

    /// Register chat section toolbar bar item
    public func registerChatSectionToolbarBarItem(_ item: ChatSectionToolbarBarItem) {
        chatSection?.registerChatSectionToolbarBarItem(item)
    }

    /// Unregister chat section toolbar bar item
    public func unregisterChatSectionToolbarBarItem(id: String) {
        chatSection?.unregisterChatSectionToolbarBarItem(id: id)
    }

    /// Register chat section header item
    public func registerChatSectionHeaderItem(_ item: ChatSectionHeaderItem) {
        chatSection?.registerChatSectionHeaderItem(item)
    }

    /// Unregister chat section header item
    public func unregisterChatSectionHeaderItem(id: String) {
        chatSection?.unregisterChatSectionHeaderItem(id: id)
    }

    // MARK: - Status Bar Convenience Accessors

    /// All registered status bar items
    public var allStatusBarItems: [StatusBarItem] {
        statusBar?.allStatusBarItems ?? []
    }

    /// Get status bar items by placement
    public func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem] {
        statusBar?.statusBarItems(placement: placement) ?? []
    }

    /// Get status bar items by placement (throws if service not available)
    public func statusBarItemsChecked(placement: StatusBarPlacement) throws -> [StatusBarItem] {
        guard let statusBarService = statusBar else {
            throw LumiKernelError.serviceNotAvailable(service: "StatusBar")
        }
        return statusBarService.statusBarItems(placement: placement)
    }

    /// Register status bar item
    public func registerStatusBarItem(_ item: StatusBarItem) {
        statusBar?.registerStatusBarItem(item)
    }

    /// Unregister status bar item
    public func unregisterStatusBarItem(id: String) {
        statusBar?.unregisterStatusBarItem(id: id)
    }

    // MARK: - Settings Convenience Accessors

    /// All registered settings tab items
    public var allSettingsTabItems: [SettingsTabItem] {
        settings?.allSettingsTabItems ?? []
    }

    /// All registered LLM provider settings items
    public var allLLMProviderSettingsItems: [LLMProviderSettingsItem] {
        settings?.allLLMProviderSettingsItems ?? []
    }

    /// Register settings tab item
    public func registerSettingsTabItem(_ item: SettingsTabItem) {
        settings?.registerSettingsTabItem(item)
    }

    /// Unregister settings tab item
    public func unregisterSettingsTabItem(id: String) {
        settings?.unregisterSettingsTabItem(id: id)
    }

    /// Register LLM provider settings item
    public func registerLLMProviderSettingsItem(_ item: LLMProviderSettingsItem) {
        settings?.registerLLMProviderSettingsItem(item)
    }

    /// Unregister LLM provider settings item
    public func unregisterLLMProviderSettingsItem(providerID: String) {
        settings?.unregisterLLMProviderSettingsItem(providerID: providerID)
    }

    // MARK: - Logo Convenience Accessors

    /// All registered logo items (sorted by order descending, higher order = higher priority)
    public var allLogoItems: [LogoItem] {
        logo?.allLogoItems ?? []
    }

    /// Register logo item
    public func registerLogoItem(_ item: LogoItem) {
        logo?.registerLogoItem(item)
    }

    /// Unregister logo item
    public func unregisterLogoItem(id: String) {
        logo?.unregisterLogoItem(id: id)
    }

    // MARK: - Onboarding Convenience Accessors

    /// All registered onboarding pages (sorted by order)
    public var allOnboardingPages: [OnboardingPageItem] {
        onboarding?.allOnboardingPages ?? []
    }

    /// Register onboarding page
    public func registerOnboardingPage(_ page: OnboardingPageItem) {
        onboarding?.registerOnboardingPage(page)
    }

    /// Unregister onboarding page
    public func unregisterOnboardingPage(id: String) {
        onboarding?.unregisterOnboardingPage(id: id)
    }

    // MARK: - Theme Convenience Accessors

    /// All registered themes
    public var allThemes: [LumiUIThemeContribution] {
        theme?.allThemes ?? []
    }

    /// Register theme
    public func registerTheme(_ contribution: LumiUIThemeContribution) {
        theme?.registerTheme(contribution)
    }

    /// Unregister theme
    public func unregisterTheme(id: String) {
        theme?.unregisterTheme(id: id)
    }

    // MARK: - Startup & Validation

    /// Startup kernel and perform self-check
    ///
    /// Checks if all required services are registered, throws error if requirements not met.
    /// - Throws: If required services are missing
    public func startup() throws {
        var missingServices: [String] = []

        if storage == nil { missingServices.append("Storage") }
        if project == nil { missingServices.append("Project") }
        if layout == nil { missingServices.append("Layout") }
        if viewContainer == nil { missingServices.append("ViewContainer") }
        if command == nil { missingServices.append("Command") }
        if menuBar == nil { missingServices.append("MenuBar") }
        if titleToolbar == nil { missingServices.append("TitleToolbar") }
        if sendMiddleware == nil { missingServices.append("SendMiddleware") }
        if chat == nil { missingServices.append("Chat") }
        if chatSection == nil { missingServices.append("ChatSection") }
        if editor == nil { missingServices.append("Editor") }
        if agentTool == nil { missingServices.append("AgentTool") }
        if panel == nil { missingServices.append("Panel") }
        if statusBar == nil { missingServices.append("StatusBar") }
        if settings == nil { missingServices.append("Settings") }
        if logo == nil { missingServices.append("Logo") }
        if theme == nil { missingServices.append("Theme") }
        if plugin == nil { missingServices.append("Plugin") }

        if !missingServices.isEmpty {
            throw LumiKernelError.missingRequiredServices(missingServices)
        }
    }
}
