import Combine
import Foundation
import SwiftUI

/// LumiCore 默认实现：`final class`，可实例化、可注入、可 mock。
///
/// - 所有公开 API 通过 `LumiCoreAccessing`（视图/插件常用）和 `LumiCoreBootstrapping`
///   （启动期一次性 API）两个协议暴露。
/// - 实例化后通过 SwiftUI `Environment(\.lumiCore)` 注入视图树，或直接持有引用。
/// - 单测时可创建独立实例（多实例隔离），或 mock 实现 `LumiCoreAccessing` 协议。
///
/// ## 使用模式
///
/// **App 启动期**：
/// ```swift
/// let core = LumiCore()
/// core.setupChatService { ChatService(...) }
/// try core.boot(databaseDirectory: ..., provider: pluginService, editorFactory: ...)
/// // 通过 .environment(\.lumiCore, core) 注入视图树
/// ```
///
/// **单元测试**（多实例隔离）：
/// ```swift
/// let core1 = LumiCore()
/// let core2 = LumiCore()
/// // 两个实例互不影响，services / projectState / layoutState 完全隔离
/// ```
@MainActor
public final class LumiCore: LumiCoreAccessing, LumiCoreBootstrapping {
    // MARK: - State

    @Published public private(set) var dataRootDirectory: URL?

    public var logoRegistry: LogoRegistry { .shared }

    @Published public private(set) var projectState: LumiProjectState?

    @Published public private(set) var layoutState: LumiLayoutState?

    @Published public private(set) var chatService: (any LumiChatServicing)?

    public internal(set) var editorService: (any AbstractEditorServicing)?

    /// 内置工具列表
    let builtInTools: [any LumiAgentTool] = [
        NoOpTool(),
        ConversationInfoTool(),
    ]

    // MARK: - Internal Storage

    /// ChatService 工厂，由外部在启动时提供；提供后，`boot()` 自动创建并注册。
    private var chatServiceFactory: ChatServiceFactory?

    /// 内部服务注册表，用于 `makePluginContext` 自动注入依赖。
    private var services: [ObjectIdentifier: Any] = [:]

    /// 空构造器（用于单测场景：创建不依赖任何服务的空实例）。
    public init() {}

    // MARK: - Configuration

    /// 配置存储根目录（创建物理目录）。
    /// - Parameter dataRootDirectory: 数据根目录路径。
    public func configure(dataRootDirectory: URL) throws {
        let directory = dataRootDirectory.standardizedFileURL
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        self.dataRootDirectory = directory
    }

    // MARK: - ChatService Factory

    /// 设置 ChatService 工厂。
    /// - Parameter factory: 工厂闭包，接收数据库目录参数，返回 ChatService 实例。
    ///   应在 `boot()` 之前调用。
    public func setupChatService(_ factory: @escaping ChatServiceFactory) {
        chatServiceFactory = factory
    }

    // MARK: - Service Registry

    /// 注册一个服务实例，供 `makePluginContext` 自动注入。
    /// 应在 `RootContainer` 初始化完成后调用一次。
    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    /// 从注册表解析已注册的服务实例。
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// 带默认参数的便利方法（供 SwiftUI 视图等使用最常用参数子集）。
    public func makePluginContext(
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
            dependencies: dependencies,
            lumiCore: self
        )
    }

    // MARK: - Boot

    /// 启动 LumiCore。
    ///
    /// 初始化所有核心模块。`editorFactory` 为可选：传入时 LumiCore 会在工具服务就绪后
    /// 自动调用工厂创建 `EditorService`，并同时注册抽象协议（`AbstractEditorServicing`）
    /// 与具体类型到服务表；不传则跳过 Editor bootstrap（适用于不需要编辑器的场景，例如
    /// 单元测试、CLI 工具）。
    ///
    /// - Parameters:
    ///   - databaseDirectory: 数据根目录。
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - editorFactory: Editor 工厂闭包，接收 provider，返回具体的 `EditorService` 实例。
    public func boot<Service: AbstractEditorServicing>(
        databaseDirectory: URL,
        provider: any LumiAgentToolProviding,
        editorFactory: EditorBootstrapFactory<Service>?
    ) throws {
        projectState = LumiProjectState()
        layoutState = LumiLayoutState()
        dataRootDirectory = databaseDirectory

        // 自动创建并注册 ChatService
        if let factory = chatServiceFactory {
            chatService = factory(databaseDirectory)
            registerService((any LumiChatServicing).self, chatService!)
            // ChatService 通常也实现 HistoryQueryService
            if let history = chatService as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }

        try configure(dataRootDirectory: databaseDirectory)

        try bootstrapToolService(provider: provider)

        // 自动创建并注册 EditorService（仅当提供了 editorFactory）
        if let editorFactory {
            try bootstrapEditor(provider: provider, factory: editorFactory)
        }
    }
}
