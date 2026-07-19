import Foundation

/// Lumi 轻量级核心
///
/// 只持有协议类型，不依赖具体实现。
/// 所有具体实现通过插件注入。
@MainActor
public final class LumiKernel: ObservableObject {
    // MARK: - Plugin Registry

    /// 插件注册表
    private var plugins: [String: LumiPlugin] = [:]

    /// 插件注册顺序（用于按顺序启动）
    private var pluginOrder: [String] = []

    /// 当前正在注册的插件（用于自动传递 order）
    private var currentRegisteringPlugin: LumiPlugin?

    // MARK: - Command Registry

    /// 命令组注册表
    private var commandGroups: [String: CommandMenuGroup] = [:]

    /// 命令组注册顺序
    private var commandGroupOrder: [String] = []

    // MARK: - Service Registry

    /// 服务注册表
    private var services: [ObjectIdentifier: Any] = [:]

    /// 菜单栏内容注册表
    private var menuBarContents: [String: MenuBarContentItem] = [:]
    private var menuBarContentOrder: [String] = []

    /// 菜单栏弹出项注册表
    private var menuBarPopups: [String: MenuBarPopupItem] = [:]
    private var menuBarPopupOrder: [String] = []

    // MARK: - Title Toolbar Registry

    /// 标题栏工具栏注册表
    private var titleToolbarItems: [String: TitleToolbarItem] = [:]
    private var titleToolbarOrder: [String] = []

    // MARK: - Send Middleware Registry

    /// 发送中间件注册表
    private var sendMiddlewares: [String: any SendMiddleware] = [:]
    private var sendMiddlewareOrder: [String] = []


    // MARK: - Service Accessors (Protocol Types)

    /// 存储服务
    public var storage: (any StorageProviding)? {
        resolveService(StorageProviding.self)
    }

    /// 项目管理服务
    public var project: (any ProjectProviding)? {
        resolveService(ProjectProviding.self)
    }

    /// 布局服务
    public var layout: (any LayoutProviding)? {
        resolveService(LayoutProviding.self)
    }

    /// 视图容器服务
    public var viewContainer: (any ViewContainerProviding)? {
        resolveService(ViewContainerProviding.self)
    }

    /// 聊天服务
    public var chat: (any ChatServiceProviding)? {
        resolveService(ChatServiceProviding.self)
    }

    /// 编辑器服务
    public var editor: (any EditorServiceProviding)? {
        resolveService(EditorServiceProviding.self)
    }

    /// Agent 工具服务
    public var agentTool: (any AgentToolProviding)? {
        resolveService(AgentToolProviding.self)
    }

    // MARK: - Initialization

    public init() {
        // 轻量级初始化，不创建任何具体实现
    }

    // MARK: - Plugin Management

    /// 注册插件
    ///
    /// 注册后会立即调用插件的 `register(kernel:)` 方法。
    /// - Parameter plugin: 要注册的插件
    /// - Throws: 如果插件已注册或注册过程中出错
    public func registerPlugin(_ plugin: LumiPlugin) throws {
        let id = plugin.id
        guard plugins[id] == nil else {
            throw LumiKernelError.pluginAlreadyRegistered(id: id)
        }

        plugins[id] = plugin
        pluginOrder.append(id)

        // 设置当前注册插件（用于自动传递 order）
        currentRegisteringPlugin = plugin

        // 立即调用注册方法
        try plugin.register(kernel: self)

        // 清除当前注册插件
        currentRegisteringPlugin = nil
    }

    /// 批量注册插件
    ///
    /// - Parameter plugins: 要注册的插件列表
    /// - Throws: 如果任一插件注册失败
    public func registerPlugins(_ plugins: [LumiPlugin]) throws {
        for plugin in plugins {
            try registerPlugin(plugin)
        }
    }

    /// 启动所有插件
    ///
    /// 调用所有已注册插件的 `boot(kernel:)` 方法。
    /// - Throws: 如果任一插件启动失败
    public func bootstrapPlugins() async throws {
        for id in pluginOrder {
            guard let plugin = plugins[id] else { continue }
            try await plugin.boot(kernel: self)
        }
    }

    // MARK: - Startup & Validation

    /// 启动内核并进行自检
    ///
    /// 检查所有必需服务是否已注册，未满足要求时抛出错误。
    /// - Throws: 如果必需服务缺失
    public func startup() throws {
        var missingServices: [String] = []

        // 检查必需服务
        if storage == nil {
            missingServices.append("Storage")
        }

        if project == nil { missingServices.append("Project") }
        if layout == nil { missingServices.append("Layout") }
        if chat == nil { missingServices.append("Chat") }
        if editor == nil { missingServices.append("Editor") }
        if agentTool == nil { missingServices.append("AgentTool") }

        if !missingServices.isEmpty {
            throw LumiKernelError.missingRequiredServices(missingServices)
        }
    }

    /// 查询已注册的插件
    ///
    /// - Parameter type: 插件类型
    /// - Returns: 匹配的插件实例，或 nil
    public func plugin<T: LumiPlugin>(ofType type: T.Type) -> T? {
        plugins.values.first(where: { $0 is T }) as? T
    }

    /// 查询已注册的插件
    ///
    /// - Parameter id: 插件 ID
    /// - Returns: 匹配的插件实例，或 nil
    public func plugin(id: String) -> LumiPlugin? {
        plugins[id]
    }

    /// 所有已注册的插件
    public var allPlugins: [LumiPlugin] {
        pluginOrder.compactMap { plugins[$0] }
    }

    // MARK: - Service Registration (Direct & Simple)

    /// 注册存储服务
    public func registerStorage(_ storage: any StorageProviding) {
        registerService(StorageProviding.self, storage)
    }

    /// 注册项目管理服务
    public func registerProject(_ project: any ProjectProviding) {
        registerService(ProjectProviding.self, project)
    }

    /// 注册布局服务
    public func registerLayout(_ layout: any LayoutProviding) {
        registerService(LayoutProviding.self, layout)
    }

    /// 注册聊天服务
    public func registerChat(_ chat: any ChatServiceProviding) {
        registerService(ChatServiceProviding.self, chat)
    }

    /// 注册编辑器服务
    public func registerEditor(_ editor: any EditorServiceProviding) {
        registerService(EditorServiceProviding.self, editor)
    }

    /// 注册 Agent 工具服务
    public func registerAgentToolService(_ agentTool: any AgentToolProviding) {
        registerService(AgentToolProviding.self, agentTool)
    }

    /// 注册视图容器服务
    public func registerViewContainerService(_ service: any ViewContainerProviding) {
        registerService(ViewContainerProviding.self, service)
    }

    // MARK: - Command Registry

    /// 注册命令组
    ///
    /// 插件可以注册多个命令组，每个组对应一个菜单。
    /// - Parameter group: 命令组
    public func registerCommandGroup(_ group: CommandMenuGroup) {
        if commandGroups[group.id] == nil {
            commandGroupOrder.append(group.id)
        }
        commandGroups[group.id] = group
    }

    /// 注册单个命令项（自动分组）
    ///
    /// 便捷方法，自动将命令添加到指定菜单组。
    /// - Parameters:
    ///   - menu: 菜单名称
    ///   - item: 命令项
    public func registerCommand(menu: String, item: CommandItem) {
        let groupId = "menu.\(menu.lowercased())"

        if let existingGroup = commandGroups[groupId] {
            // 已存在该菜单组，追加命令项
            var items = existingGroup.items
            items.append(item)
            commandGroups[groupId] = CommandMenuGroup(id: groupId, name: menu, items: items)
        } else {
            // 创建新的菜单组
            commandGroups[groupId] = CommandMenuGroup(id: groupId, name: menu, items: [item])
            commandGroupOrder.append(groupId)
        }
    }

    /// 所有已注册的命令组
    public var allCommandGroups: [CommandMenuGroup] {
        commandGroupOrder.compactMap { commandGroups[$0] }
    }

    /// 按菜单名查询命令组
    public func commandGroup(named name: String) -> CommandMenuGroup? {
        commandGroups["menu.\(name.lowercased())"]
    }

    // MARK: - Generic Service Registry

    /// 注册服务实现
    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    /// 解析服务实现
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// 注销服务
    public func unregisterService<T>(_ type: T.Type) {
        services.removeValue(forKey: ObjectIdentifier(type))
    }

    // MARK: - View Container Registry

    /// 所有已注册的视图容器（按 order 排序）
    public var allViewContainers: [ViewContainerItem] {
        viewContainer?.allViewContainers ?? []
    }

    /// 注册视图容器
    public func registerViewContainer(_ container: ViewContainerItem) {
        var container = container
        // 自动从插件继承 order
        if let pluginOrder = currentRegisteringPlugin?.order {
            container.order = pluginOrder
        }
        viewContainer?.register(container)
    }

    /// 注销视图容器
    public func unregisterViewContainer(id: String) {
        viewContainer?.unregister(id: id)
    }

    // MARK: - Menu Bar Content Registry

    /// 所有已注册的菜单栏内容（按 order 排序）
    public var allMenuBarContents: [MenuBarContentItem] {
        menuBarContentOrder.compactMap { menuBarContents[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册菜单栏内容
    public func registerMenuBarContent(_ content: MenuBarContentItem) {
        var content = content
        // 自动从插件继承 order
        if let pluginOrder = currentRegisteringPlugin?.order {
            content.order = pluginOrder
        }
        if menuBarContents[content.id] == nil {
            menuBarContentOrder.append(content.id)
        }
        menuBarContents[content.id] = content
    }

    /// 注销菜单栏内容
    public func unregisterMenuBarContent(id: String) {
        menuBarContents.removeValue(forKey: id)
        menuBarContentOrder.removeAll { $0 == id }
    }

    // MARK: - Menu Bar Popup Registry

    /// 所有已注册的菜单栏弹出项（按 order 排序）
    public var allMenuBarPopups: [MenuBarPopupItem] {
        menuBarPopupOrder.compactMap { menuBarPopups[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册菜单栏弹出项
    public func registerMenuBarPopup(_ popup: MenuBarPopupItem) {
        var popup = popup
        // 自动从插件继承 order
        if let pluginOrder = currentRegisteringPlugin?.order {
            popup.order = pluginOrder
        }
        if menuBarPopups[popup.id] == nil {
            menuBarPopupOrder.append(popup.id)
        }
        menuBarPopups[popup.id] = popup
    }

    /// 注销菜单栏弹出项
    public func unregisterMenuBarPopup(id: String) {
        menuBarPopups.removeValue(forKey: id)
        menuBarPopupOrder.removeAll { $0 == id }
    }

    // MARK: - Title Toolbar Registry

    /// 所有已注册的标题栏工具栏项（按 order 排序）
    public var allTitleToolbarItems: [TitleToolbarItem] {
        titleToolbarOrder.compactMap { titleToolbarItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 按位置获取标题栏工具栏项
    public func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem] {
        allTitleToolbarItems.filter { $0.placement == placement }
    }

    /// 注册标题栏工具栏项
    public func registerTitleToolbarItem(_ item: TitleToolbarItem) {
        var item = item
        // 自动从插件继承 order
        if let pluginOrder = currentRegisteringPlugin?.order {
            item.order = pluginOrder
        }
        if titleToolbarItems[item.id] == nil {
            titleToolbarOrder.append(item.id)
        }
        titleToolbarItems[item.id] = item
    }

    /// 注销标题栏工具栏项
    public func unregisterTitleToolbarItem(id: String) {
        titleToolbarItems.removeValue(forKey: id)
        titleToolbarOrder.removeAll { $0 == id }
    }

    // MARK: - Send Middleware Registry

    /// 所有已注册的发送中间件
    public var allSendMiddlewares: [any SendMiddleware] {
        sendMiddlewareOrder.compactMap { sendMiddlewares[$0] }
    }

    /// 注册发送中间件
    public func registerSendMiddleware(_ middleware: any SendMiddleware, id: String? = nil) {
        let middlewareId = id ?? UUID().uuidString
        if sendMiddlewares[middlewareId] == nil {
            sendMiddlewareOrder.append(middlewareId)
        }
        sendMiddlewares[middlewareId] = middleware
    }

    /// 注销发送中间件
    public func unregisterSendMiddleware(id: String) {
        sendMiddlewares.removeValue(forKey: id)
        sendMiddlewareOrder.removeAll { $0 == id }
    }

    // MARK: - Agent Tool Registry (Individual)

    /// 所有已注册的 Agent 工具
    public var allAgentTools: [any LumiAgentTool] {
        agentTool?.allAgentTools ?? []
    }

    /// 注册单个 Agent 工具
    public func registerAgentTool(_ tool: any LumiAgentTool) {
        agentTool?.register(tool)
    }

    /// 注销 Agent 工具
    public func unregisterAgentTool(id: String) {
        agentTool?.unregister(id: id)
    }


    // MARK: - Panel Registry

    /// 面板顶部标题栏项注册表
    private var panelHeaderItems: [String: PanelHeaderItem] = [:]
    private var panelHeaderItemOrder: [String] = []

    /// 面板底部标签项注册表
    private var panelBottomTabItems: [String: PanelBottomTabItem] = [:]
    private var panelBottomTabItemOrder: [String] = []

    /// 侧边栏标签项注册表
    private var panelRailTabItems: [String: PanelRailTabItem] = [:]
    private var panelRailTabItemOrder: [String] = []

    // MARK: - Chat Section Registry

    /// 聊天分区项注册表
    private var chatSectionItems: [String: ChatSectionItem] = [:]
    private var chatSectionItemOrder: [String] = []

    /// 聊天分区工具栏项注册表
    private var chatSectionToolbarItems: [String: ChatSectionToolbarItem] = [:]
    private var chatSectionToolbarItemOrder: [String] = []

    /// 聊天分区工具栏条注册表
    private var chatSectionToolbarBarItems: [String: ChatSectionToolbarBarItem] = [:]
    private var chatSectionToolbarBarItemOrder: [String] = []

    /// 聊天分区标题项注册表
    private var chatSectionHeaderItems: [String: ChatSectionHeaderItem] = [:]
    private var chatSectionHeaderItemOrder: [String] = []

    // MARK: - Status Bar Registry

    /// 状态栏项注册表
    private var statusBarItems: [String: StatusBarItem] = [:]
    private var statusBarItemOrder: [String] = []

    // MARK: - Settings Tab Registry

    /// 设置标签项注册表
    private var settingsTabItems: [String: SettingsTabItem] = [:]
    private var settingsTabItemOrder: [String] = []

    // MARK: - LLM Provider Settings Registry

    /// LLM 提供商设置项注册表
    private var llmProviderSettingsItems: [String: LLMProviderSettingsItem] = [:]
    private var llmProviderSettingsItemOrder: [String] = []

    // MARK: - Logo Registry

    /// Logo 项注册表
    private var logoItems: [String: LogoItem] = [:]
    private var logoItemOrder: [String] = []

    // MARK: - Panel Accessors

    /// 所有已注册的面板顶部标题栏项
    public var allPanelHeaderItems: [PanelHeaderItem] {
        panelHeaderItemOrder.compactMap { panelHeaderItems[$0] }
    }

    /// 注册面板顶部标题栏项
    public func registerPanelHeaderItem(_ item: PanelHeaderItem) {
        if panelHeaderItems[item.id] == nil {
            panelHeaderItemOrder.append(item.id)
        }
        panelHeaderItems[item.id] = item
    }

    /// 注销面板顶部标题栏项
    public func unregisterPanelHeaderItem(id: String) {
        panelHeaderItems.removeValue(forKey: id)
        panelHeaderItemOrder.removeAll { $0 == id }
    }

    /// 所有已注册的面板底部标签项（按 order 排序）
    public var allPanelBottomTabItems: [PanelBottomTabItem] {
        panelBottomTabItemOrder.compactMap { panelBottomTabItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册面板底部标签项
    public func registerPanelBottomTabItem(_ item: PanelBottomTabItem) {
        if panelBottomTabItems[item.id] == nil {
            panelBottomTabItemOrder.append(item.id)
        }
        panelBottomTabItems[item.id] = item
    }

    /// 注销面板底部标签项
    public func unregisterPanelBottomTabItem(id: String) {
        panelBottomTabItems.removeValue(forKey: id)
        panelBottomTabItemOrder.removeAll { $0 == id }
    }

    /// 所有已注册的侧边栏标签项（按 order 排序）
    public var allPanelRailTabItems: [PanelRailTabItem] {
        panelRailTabItemOrder.compactMap { panelRailTabItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册侧边栏标签项
    public func registerPanelRailTabItem(_ item: PanelRailTabItem) {
        if panelRailTabItems[item.id] == nil {
            panelRailTabItemOrder.append(item.id)
        }
        panelRailTabItems[item.id] = item
    }

    /// 注销侧边栏标签项
    public func unregisterPanelRailTabItem(id: String) {
        panelRailTabItems.removeValue(forKey: id)
        panelRailTabItemOrder.removeAll { $0 == id }
    }

    // MARK: - Chat Section Accessors

    /// 所有已注册的聊天分区项（按 order 排序）
    public var allChatSectionItems: [ChatSectionItem] {
        chatSectionItemOrder.compactMap { chatSectionItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 按位置获取聊天分区项
    public func chatSectionItems(placement: ChatSectionPlacement) -> [ChatSectionItem] {
        allChatSectionItems.filter { $0.placement == placement }
    }

    /// 注册聊天分区项
    public func registerChatSectionItem(_ item: ChatSectionItem) {
        if chatSectionItems[item.id] == nil {
            chatSectionItemOrder.append(item.id)
        }
        chatSectionItems[item.id] = item
    }

    /// 注销聊天分区项
    public func unregisterChatSectionItem(id: String) {
        chatSectionItems.removeValue(forKey: id)
        chatSectionItemOrder.removeAll { $0 == id }
    }

    /// 所有已注册的聊天分区工具栏项（按 order 排序）
    public var allChatSectionToolbarItems: [ChatSectionToolbarItem] {
        chatSectionToolbarItemOrder.compactMap { chatSectionToolbarItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 按位置获取聊天分区工具栏项
    public func chatSectionToolbarItems(placement: ChatSectionToolbarPlacement) -> [ChatSectionToolbarItem] {
        allChatSectionToolbarItems.filter { $0.placement == placement }
    }

    /// 注册聊天分区工具栏项
    public func registerChatSectionToolbarItem(_ item: ChatSectionToolbarItem) {
        if chatSectionToolbarItems[item.id] == nil {
            chatSectionToolbarItemOrder.append(item.id)
        }
        chatSectionToolbarItems[item.id] = item
    }

    /// 注销聊天分区工具栏项
    public func unregisterChatSectionToolbarItem(id: String) {
        chatSectionToolbarItems.removeValue(forKey: id)
        chatSectionToolbarItemOrder.removeAll { $0 == id }
    }

    /// 所有已注册的聊天分区工具栏条（按 order 排序）
    public var allChatSectionToolbarBarItems: [ChatSectionToolbarBarItem] {
        chatSectionToolbarBarItemOrder.compactMap { chatSectionToolbarBarItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册聊天分区工具栏条
    public func registerChatSectionToolbarBarItem(_ item: ChatSectionToolbarBarItem) {
        if chatSectionToolbarBarItems[item.id] == nil {
            chatSectionToolbarBarItemOrder.append(item.id)
        }
        chatSectionToolbarBarItems[item.id] = item
    }

    /// 注销聊天分区工具栏条
    public func unregisterChatSectionToolbarBarItem(id: String) {
        chatSectionToolbarBarItems.removeValue(forKey: id)
        chatSectionToolbarBarItemOrder.removeAll { $0 == id }
    }

    /// 所有已注册的聊天分区标题项（按 order 排序）
    public var allChatSectionHeaderItems: [ChatSectionHeaderItem] {
        chatSectionHeaderItemOrder.compactMap { chatSectionHeaderItems[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册聊天分区标题项
    public func registerChatSectionHeaderItem(_ item: ChatSectionHeaderItem) {
        if chatSectionHeaderItems[item.id] == nil {
            chatSectionHeaderItemOrder.append(item.id)
        }
        chatSectionHeaderItems[item.id] = item
    }

    /// 注销聊天分区标题项
    public func unregisterChatSectionHeaderItem(id: String) {
        chatSectionHeaderItems.removeValue(forKey: id)
        chatSectionHeaderItemOrder.removeAll { $0 == id }
    }

    // MARK: - Status Bar Accessors

    /// 所有已注册的状态栏项（按注册顺序）
    public var allStatusBarItems: [StatusBarItem] {
        statusBarItemOrder.compactMap { statusBarItems[$0] }
    }

    /// 按位置获取状态栏项
    public func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem] {
        allStatusBarItems.filter { $0.placement == placement }
    }

    /// 注册状态栏项
    public func registerStatusBarItem(_ item: StatusBarItem) {
        if statusBarItems[item.id] == nil {
            statusBarItemOrder.append(item.id)
        }
        statusBarItems[item.id] = item
    }

    /// 注销状态栏项
    public func unregisterStatusBarItem(id: String) {
        statusBarItems.removeValue(forKey: id)
        statusBarItemOrder.removeAll { $0 == id }
    }

    // MARK: - Settings Tab Accessors

    /// 所有已注册的设置标签项（按注册顺序）
    public var allSettingsTabItems: [SettingsTabItem] {
        settingsTabItemOrder.compactMap { settingsTabItems[$0] }
    }

    /// 注册设置标签项
    public func registerSettingsTabItem(_ item: SettingsTabItem) {
        if settingsTabItems[item.id] == nil {
            settingsTabItemOrder.append(item.id)
        }
        settingsTabItems[item.id] = item
    }

    /// 注销设置标签项
    public func unregisterSettingsTabItem(id: String) {
        settingsTabItems.removeValue(forKey: id)
        settingsTabItemOrder.removeAll { $0 == id }
    }

    // MARK: - LLM Provider Settings Accessors

    /// 所有已注册的 LLM 提供商设置项（按注册顺序）
    public var allLLMProviderSettingsItems: [LLMProviderSettingsItem] {
        llmProviderSettingsItemOrder.compactMap { llmProviderSettingsItems[$0] }
    }

    /// 注册 LLM 提供商设置项
    public func registerLLMProviderSettingsItem(_ item: LLMProviderSettingsItem) {
        if llmProviderSettingsItems[item.providerID] == nil {
            llmProviderSettingsItemOrder.append(item.providerID)
        }
        llmProviderSettingsItems[item.providerID] = item
    }

    /// 注销 LLM 提供商设置项
    public func unregisterLLMProviderSettingsItem(providerID: String) {
        llmProviderSettingsItems.removeValue(forKey: providerID)
        llmProviderSettingsItemOrder.removeAll { $0 == providerID }
    }

    // MARK: - Logo Accessors

    /// 所有已注册的 Logo 项（按 order 降序，order 越大优先级越高）
    public var allLogoItems: [LogoItem] {
        logoItemOrder.compactMap { logoItems[$0] }
            .sorted { $0.order > $1.order }
    }

    /// 注册 Logo 项
    public func registerLogoItem(_ item: LogoItem) {
        if logoItems[item.id] == nil {
            logoItemOrder.append(item.id)
        }
        logoItems[item.id] = item
    }

    /// 注销 Logo 项
    public func unregisterLogoItem(id: String) {
        logoItems.removeValue(forKey: id)
        logoItemOrder.removeAll { $0 == id }
    }
}
