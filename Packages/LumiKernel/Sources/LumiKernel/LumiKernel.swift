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

    // MARK: - Command Registry

    /// 命令组注册表
    private var commandGroups: [String: CommandMenuGroup] = [:]

    /// 命令组注册顺序
    private var commandGroupOrder: [String] = []

    // MARK: - Service Registry

    /// 服务注册表
    private var services: [ObjectIdentifier: Any] = [:]

    // MARK: - View Container Registry

    /// 视图容器注册表
    private var viewContainers: [String: ViewContainerItem] = [:]
    private var viewContainerOrder: [String] = []

    /// 菜单栏内容注册表
    private var menuBarContents: [String: MenuBarContentItem] = [:]
    private var menuBarContentOrder: [String] = []

    /// 菜单栏弹出项注册表
    private var menuBarPopups: [String: MenuBarPopupItem] = [:]
    private var menuBarPopupOrder: [String] = []

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

        // 立即调用注册方法
        try plugin.register(kernel: self)
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
    public func registerAgentTool(_ agentTool: any AgentToolProviding) {
        registerService(AgentToolProviding.self, agentTool)
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
        viewContainerOrder.compactMap { viewContainers[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册视图容器
    public func registerViewContainer(_ container: ViewContainerItem) {
        if viewContainers[container.id] == nil {
            viewContainerOrder.append(container.id)
        }
        viewContainers[container.id] = container
    }

    /// 注销视图容器
    public func unregisterViewContainer(id: String) {
        viewContainers.removeValue(forKey: id)
        viewContainerOrder.removeAll { $0 == id }
    }

    // MARK: - Menu Bar Content Registry

    /// 所有已注册的菜单栏内容（按 order 排序）
    public var allMenuBarContents: [MenuBarContentItem] {
        menuBarContentOrder.compactMap { menuBarContents[$0] }
            .sorted { $0.order < $1.order }
    }

    /// 注册菜单栏内容
    public func registerMenuBarContent(_ content: MenuBarContentItem) {
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
}

// MARK: - Errors

/// LumiKernel 错误
public enum LumiKernelError: Error, LocalizedError {
    case pluginAlreadyRegistered(id: String)
    case pluginNotFound(id: String)
    case missingRequiredServices([String])

    public var errorDescription: String? {
        switch self {
        case .pluginAlreadyRegistered(let id):
            return "Plugin '\(id)' is already registered"
        case .pluginNotFound(let id):
            return "Plugin '\(id)' not found"
        case .missingRequiredServices(let services):
            return "Missing required services: \(services.joined(separator: ", "))"
        }
    }
}
