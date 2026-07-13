import Combine
import Foundation
import SwiftUI

@MainActor
public enum LumiCore {
    private static var configuration: LumiCoreConfiguration?

    /// Logo 注册表（指向 `LogoRegistry.shared` 单例）
    @MainActor public static var logoRegistry: LogoRegistry { .shared }

    /// 项目状态管理器
    @MainActor public private(set) static var projectState: LumiProjectState?

    /// 布局状态管理器
    @MainActor public private(set) static var layoutState: LumiLayoutState?

    /// 聊天服务（由外部通过 `setupChatService` 工厂创建，自动注册到服务表）
    @MainActor public private(set) static var chatService: (any LumiChatServicing)?

    /// ChatService 工厂闭包类型
    public typealias ChatServiceFactory = @MainActor (URL) -> any LumiChatServicing

    /// ChatService 工厂，由 LumiApp 在启动时提供。
    /// 提供后，LumiCore 在 boot() 时自动创建并注册到服务表。
    private static var chatServiceFactory: ChatServiceFactory?

    /// 设置 ChatService 工厂。
    /// - Parameters:
    ///   - factory: 工厂闭包，接收数据库目录参数，返回 ChatService 实例。
    ///   - 应在 `LumiCore.boot()` 之前调用。
    public static func setupChatService(_ factory: @escaping ChatServiceFactory) {
        chatServiceFactory = factory
    }

    // MARK: - Service Registry

    /// 内部服务注册表，用于 `makePluginContext` 自动注入依赖。
    @MainActor private static var services: [ObjectIdentifier: Any] = [:]

    /// 注册一个服务实例，供 `LumiCore.makePluginContext` 自动注入。
    /// - 应在 `RootContainer` 初始化完成后调用一次。
    public static func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    /// 从注册表解析已注册的服务实例。
    public static func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    // MARK: - Plugin Context Factory

    /// 统一创建 `LumiPluginContext`。
    /// 基础服务（如 `LumiChatServicing`、`LumiToolServicing` 等）由 `LumiCore` 自动注入。
    /// App 层自定义服务可通过 `additionalDependencies` 手动注入。
    /// - Parameters:
    ///   - activeSectionID: 当前活跃区域 ID。
    ///   - activeSectionTitle: 当前活跃区域标题。
    ///   - chatSection: 聊天区布局配置。
    ///   - showsRail: 是否显示侧边栏。
    ///   - showsPanelChrome: 是否显示面板边框。
    ///   - isChatSectionVisible: 聊天区是否可见。
    ///   - additionalDependencies: 依赖注册回调，用于注入外部服务。
    /// - Returns: 初始化完成的 `LumiPluginContext`。
    public static func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        additionalDependencies: (inout LumiPluginDependencies) -> Void = { _ in }
    ) -> LumiPluginContext {
        var dependencies = LumiPluginDependencies()

        // 基础服务自动注入（仅 LumiCoreKit 内部定义的服务）
        if let chat = resolveService((any LumiChatServicing).self) {
            dependencies.register((any LumiChatServicing).self, chat)
        }
        if let toolService = resolveService((any LumiToolServicing).self) {
            dependencies.register((any LumiToolServicing).self, toolService)
        }
        if let history = resolveService((any HistoryQueryService).self) {
            dependencies.register((any HistoryQueryService).self, history)
        }
        if let presenter = resolveService(LumiBottomPanelLayoutPresenting.self) {
            dependencies.register(LumiBottomPanelLayoutPresenting.self, presenter)
        }
        if let providerSettings = resolveService((any LumiLLMProviderSettingsContributing).self) {
            dependencies.register((any LumiLLMProviderSettingsContributing).self, providerSettings)
        }

        // 外部服务由调用者手动注入
        additionalDependencies(&dependencies)

        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies
        )
    }

    // MARK: - 启动

    /// 启动 LumiCore。
    ///
    /// 初始化所有核心模块。`editorFactory` 为可选：传入时 `LumiCore` 会在工具服务就绪后
    /// 自动调用工厂创建 `EditorService`，并同时注册抽象协议（`AbstractEditorServicing`）
    /// 与具体类型到服务表；不传则跳过 Editor bootstrap（适用于不需要编辑器的场景，例如
    /// 单元测试、CLI 工具）。
    ///
    /// - Parameters:
    ///   - databaseDirectory: 数据根目录。
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - editorFactory: Editor 工厂闭包，接收 provider，返回具体的 `EditorService` 实例。
    public static func boot<Service: AbstractEditorServicing>(
        databaseDirectory: URL,
        provider: any LumiAgentToolProviding,
        editorFactory: EditorBootstrapFactory<Service>? = nil
    ) throws {
        projectState = LumiProjectState()
        layoutState = LumiLayoutState()

        // 自动创建并注册 ChatService
        if let factory = chatServiceFactory {
            chatService = factory(databaseDirectory)
            registerService((any LumiChatServicing).self, chatService!)
            // ChatService 通常也实现 HistoryQueryService
            if let history = chatService as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }

        try self.configure(dataRootDirectory: databaseDirectory)

        try bootstrapToolService(provider: provider)

        // 自动创建并注册 EditorService（仅当提供了 editorFactory）
        if let editorFactory {
            try bootstrapEditor(provider: provider, factory: editorFactory)
        }
    }
}