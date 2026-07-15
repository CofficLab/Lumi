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

    @Published public private(set) var projectState: LumiProjectState? {
        didSet { subscribeToChild(projectState, into: &projectStateSubscription) }
    }

    @Published public private(set) var layoutState: LumiLayoutState? {
        didSet { subscribeToChild(layoutState, into: &layoutStateSubscription) }
    }

    @Published public private(set) var chatService: (any LumiChatServicing)?

    public internal(set) var editorService: (any AbstractEditorServicing)?

    // MARK: - Internal Storage

    /// ChatService 工厂，由外部在启动时提供；提供后，`boot()` 自动创建并注册。
    private var chatServiceFactory: ChatServiceFactory?

    /// 内部服务注册表，用于 `makePluginContext` 自动注入依赖。
    private var services: [ObjectIdentifier: Any] = [:]

    /// 内部 `ObservableObject` 子状态（`projectState` / `layoutState`）的
    /// `objectWillChange` 转发订阅。把它们的变更信号桥接到 `LumiCore.objectWillChange`，
    /// 这样用 `@ObservedObject var lumiCore: LumiCore` 的 SwiftUI 视图（如 `AppLayoutView`）
    /// 才能在子状态变更时收到刷新信号——否则只观察 `LumiCore` 的 @Published 是收不到的
    /// （`@Published` 只会在引用本身重新赋值时 fire，子状态的属性变化不穿透）。
    ///
    /// 注意：`chatService` 类型是 `any LumiChatServicing`，存在类型的关联类型会被擦除成
    /// `any Publisher`，`sink` 不可用，因此暂不做转发。`chatService` 在视图层通常以
    /// `let` 注入（见 `AppLayoutView`），不通过 `@ObservedObject` 监听，所以不会触发
    /// "UI 不刷新" 的同款问题；需要时可在 `LumiChatServicing` 实现里手动 `objectWillChange.send()`。
    private var projectStateSubscription: AnyCancellable?
    private var layoutStateSubscription: AnyCancellable?

    /// 订阅具体类型的子 `ObservableObject`（`LumiProjectState` / `LumiLayoutState`）的
    /// `objectWillChange`，转发到本实例的 `objectWillChange`。
    /// - Parameters:
    ///   - child: 子状态实例（nil 时清空旧订阅，避免对已释放对象持有强引用）。
    ///   - subscription: 用于保存订阅句柄的 `inout` 引用，保证同一时间最多一份活跃订阅。
    private func subscribeToChild<T: ObservableObject>(
        _ child: T?,
        into subscription: inout AnyCancellable?
    ) {
        guard let child else {
            subscription = nil
            return
        }
        subscription = child.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    /// 空构造器（用于单测场景：创建不依赖任何服务的空实例）。
    public init() {}

    // MARK: - Test-only injection

    #if DEBUG
    /// 仅 DEBUG 编译下可见的内部状态注入器，用于单元测试验证 `objectWillChange` 转发链。
    /// 运行时不会暴露（release build 中直接消失），无 ABI 影响。
    internal func _testInject(layoutState: LumiLayoutState?) {
        self.layoutState = layoutState
    }
    internal func _testInject(projectState: LumiProjectState?) {
        self.projectState = projectState
    }
    #endif

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
