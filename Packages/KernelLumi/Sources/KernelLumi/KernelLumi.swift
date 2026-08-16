import Combine
import Foundation
import LumiUI
import SwiftUI

/// Lumi lightweight core
///
/// Architecture principle: Kernel 只持有各类能力（Provider），不进行能力转发。
/// 错误示例: kernel.getMessageList() — 这会让 Kernel 无限膨胀
/// 正确示例: kernel.messageManager.getMessageList() — 能力委托给具体 Provider
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class KernelLumiContainer: ObservableObject {

    // MARK: - Service Registry

    /// Service registry
    private var services: [ObjectIdentifier: Any] = [:]

    /// Service change subscriptions
    private var serviceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    /// 内置插件管理器（直接持有，不使用服务注册表）
    public let pluginManager: PluginManager

    /// 内核统一事件分发器。
    public let eventManager: EventManager

    /// 内核协调器注册表(Coordinators/ 层)。
    ///
    /// 协调器把"服务 A 的变化引发服务 B 的动作"这类内核内部联动集中装配:
    /// `startup()` 在插件服务注册完毕后调用 `startAll`,统一校验依赖、
    /// 构造编排器并把编排结果注册回内核。当前无内置协调器(发送等链路由
    /// 插件实现),保留此注册表供将来纯内核实现的联动链登记。详见 `LumiCoordinator`。
    public let coordinatorRegistry: LumiCoordinatorRegistry

    /// 是否在 `startup()` 中强制要求全部 13 个核心服务都已注册。
    ///
    /// 默认 `true`：完整内核（Lumi / macOS BookletMaker）链接了全部服务插件，
    /// 缺失即视为配置错误并抛出。单用途 app（如 iOS BookletMaker 只链接部分
    /// 服务插件）可置为 `false`：`startup()` 跳过该校验，依赖缺失服务的聚合
    /// 步骤会优雅 no-op。macOS 行为不受影响。
    public var requiresAllCoreServices: Bool = true

    // MARK: - Initialization

    public init() {
        // 初始化内置插件管理器（先创建，再设置 kernel 引用）
        self.eventManager = EventManager()
        self.pluginManager = PluginManager()
        self.coordinatorRegistry = LumiCoordinatorRegistry.makeDefault()
        self.pluginManager.kernel = self
    }

    // MARK: - Generic Service Registry

    /// Register service implementation
    public func registerService<T>(_ type: T.Type, _ instance: T) throws {
        try registerService(type, instance, forwardsObjectWillChange: true)
    }

    /// 注册服务，可选择是否把服务的 `objectWillChange` 转发到 kernel。
    ///
    /// 高频变更的服务（如流式输出 store：每个 LLM token 都触发 objectWillChange）
    /// 应传 `forwardsObjectWillChange: false`——否则 kernel 会把这种高频更新广播给
    /// 所有订阅 kernel 的视图（20+），导致整个 app 跟着重渲染、UI 卡顿。
    /// 此类服务改由消费方用 `Observable*Box` 精确订阅（窄播）。
    public func registerService<T>(
        _ type: T.Type,
        _ instance: T,
        forwardsObjectWillChange: Bool
    ) throws {
        let key = ObjectIdentifier(type)
        if services[key] != nil {
            throw KernelLumiError.serviceAlreadyRegistered(type: type)
        }
        services[key] = instance

        // 仅在需要时转发 objectWillChange;高频服务应 opt-out 以避免全局广播。
        if forwardsObjectWillChange {
            subscribeToObjectWillChange(observable: instance, key: key)
        }
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

    /// 指定服务类型是否已注册(协调器装配前的依赖校验用)。
    public func isServiceRegistered(_ id: ObjectIdentifier) -> Bool {
        services[id] != nil
    }

    /// Unregister service
    public func unregisterService<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        services.removeValue(forKey: key)
        serviceSubscriptions.removeValue(forKey: key)
    }

    // MARK: - Startup & Validation

    /// Startup kernel and perform self-check
    public func startup() async throws {
        // 1. 插件系统 On Boot — 阶段 1:注册内核服务与 UI 贡献
        try await pluginManager.onBoot(kernel: self)

        // 1.5 提示词聚合服务:内核提供默认实现（插件可在 onBoot 中覆盖）。
        if promptSuggestions == nil {
            try registerPromptSuggestionService(PromptSuggestionManager())
        }

        if requiresAllCoreServices {
            // 2. 服务校验 — 完整内核必须在 OnBoot 阶段注册全部 13 个核心服务。
            guard storage != nil,
                  project != nil,
                  workspace != nil,
                  command != nil,
                  messageSender != nil,
                  llmProvider != nil,
                  agentTurnManager != nil,
                  editorProvider != nil,
                  toolManager != nil,
                  settings != nil,
                  logo != nil,
                  theme != nil,
                  messageRendererManager != nil else {
                let missingServices = [
                    storage == nil ? "Storage" : nil,
                    project == nil ? "Project" : nil,
                    workspace == nil ? "Workspace" : nil,
                    command == nil ? "Command" : nil,
                    messageSender == nil ? "MessageSend" : nil,
                    llmProvider == nil ? "LLMProvider" : nil,
                    agentTurnManager == nil ? "AgentTurnManager" : nil,
                    editorProvider == nil ? "Editor" : nil,
                    toolManager == nil ? "AgentTool" : nil,
                    settings == nil ? "Settings" : nil,
                    logo == nil ? "Logo" : nil,
                    theme == nil ? "Theme" : nil,
                    messageRendererManager == nil ? "MessageRendererManager" : nil,
                ].compactMap { $0 }
                throw KernelLumiError.missingRequiredServices(missingServices)
            }
        }

        // 3. 插件系统 On Ready — 阶段 2:依赖服务的异步初始化
        try await pluginManager.onReady(kernel: self)

        // 4. 协调层装配 — 当前无内置协调器(makeDefault 为空);
        //    保留调用点,将来某条纯内核实现的联动链登记后即在此装配。
        try coordinatorRegistry.startAll(kernel: self)

        // 5. 收集所有插件贡献的 Agent 工具,并注册到内核 ToolManaging。
        //    精简宿主（requiresAllCoreServices == false）可以不提供 Agent 栈，
        //    此时跳过工具收集；完整宿主的缺失已在上方服务校验中报错。
        //    — 必须在 registerPluginUIContributions 之前执行,确保
        //    settingsTabItems 等 UI 贡献在创建时能读取到已注册的工具列表。
        if toolManager != nil {
            try pluginManager.registerAgentTools(in: self)
        }

        // 6. 收集所有插件贡献的 UI 视图,并注册到内核的共享 UI 服务
        pluginManager.registerPluginUIContributions(in: self)

        // 6.5 收集所有插件贡献的聊天起始提示词,并注册到内核 PromptSuggestionProviding。
        pluginManager.registerPromptSuggestions(in: self)

        // 7. 收集所有插件贡献的 Command 菜单组,并注册到内核 CommandProviding
        pluginManager.registerPluginCommandContributions(in: self)

        // 8. 收集所有插件贡献的 LLM Provider,并注册到内核 LLMProviderManaging。
        //    与 Agent 工具一样，精简宿主未链接 LLM 栈时直接跳过。
        if llmProvider != nil {
            try pluginManager.registerLLMProviders(in: self)
        }

        // 9. 装配编辑器贡献包（契约 V2）：按插件原子安装/撤回。
        pluginManager.registerEditorContributionBundles(in: self)

        // 10. 同步当前激活容器的可见性状态
        //    — 从 WorkspaceProviding 获取 activeViewContainerID,
        //    — 再从 WorkspaceProviding 获取该容器的 rail/chat/content/panel 可见性,
        //    — 最后更新到 WorkspaceProviding 的状态中。
        if let containerID = workspace?.activeViewContainerID {
            workspace?.applyContainerVisibility(for: containerID)
        }

        // 11. 将工作区服务中已收集的菜单栏视图交给展示层
        refreshMenuBarPresentation()

        // 12. 将内核主题服务持有的主题贡献同步到 LumiUI 的主题注册中心
        //    此时所有插件的 onReady 已执行完毕,主题贡献已注册到内核
        theme?.syncToLumiUI()

        // 13. 收集所有插件贡献的 Web 路由,并注册到内核 WebServerProviding。
        //     Web 服务为可选增强:未注册任何实现时为 no-op,不影响其它贡献。
        pluginManager.registerWebRoutes(in: self)
    }

    /// 让菜单栏展示层刷新为当前工作区服务收集到的内容。
    public func refreshMenuBarPresentation() {
        guard let presenter = menuBarPresenter else { return }
        presenter.refreshMenuBar(
            contentItems: workspace?.allMenuBarContents ?? [],
            popupItems: workspace?.allMenuBarPopups ?? []
        )
    }

    /// 卸载菜单栏展示层。
    public func dismissMenuBarPresentation() {
        menuBarPresenter?.dismissMenuBar()
    }
}

/// 兼容旧代码: 用 KernelLumi 实例化时,使用 KernelLumiContainer。
public typealias KernelLumi = KernelLumiContainer
