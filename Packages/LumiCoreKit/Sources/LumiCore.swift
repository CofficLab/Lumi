import Combine
import Foundation
import SwiftUI

@MainActor
public final class LumiCore: LumiCoreAccessing, LumiCoreBootstrapping {
    // MARK: - Active Instance

    /// 当前活跃的 `LumiCore` 实例，供无法接收 `LumiPluginContext` 的静态代码（例如
    /// `static let shared = XxxLocalStore()` 这类单例）解析存储路径。
    ///
    /// 由 `LumiCoreService` 在 `init` 末尾、boot 完成后设置。应用同一时刻通常只有一个
    /// `LumiCore` 实例在跑（参见 `final class` 文档中的"单实例 App，多实例单测"约定），
    /// 所以静态指针在这里是安全的——它指向"当前活跃"那个实例，而不是一个独立的全局对象。
    /// 仍然推荐在能拿到 `LumiPluginContext` 的地方用 `context.lumiCore`；`current` 是
    /// 给静态单例的兜底。
    public nonisolated(unsafe) static var current: (any LumiCoreAccessing)?
    
    // MARK: - Components

    // MARK: - State

    @Published public private(set) var dataRootDirectory: URL?

    public var logoRegistry: LogoRegistry { .shared }

    @Published public private(set) var projectState: ProjectState? {
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

        internal func _testInject(projectState: ProjectState?) {
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
    /// `dataRootDirectory` 是 LumiAppKit 决定并传入的数据根父目录（例如
    /// `<AppSupport>/<bundleID>/db_debug_v4/`）。LumiCore 负责在其下创建 `Core/` 子目录
    /// 作为核心数据库的物理位置，并把该子目录作为参数喂给 `ChatServiceFactory`。
    /// `LumiCore.dataRootDirectory` 始终是传入的父目录本身（而非 `Core/` 子目录），
    /// 这样 `coreDataDirectory` / `pluginDataDirectory(for:)` 的相对路径计算才能落
    /// 到历史一致的位置。
    ///
    /// `builtInTools` 是运行期会由 `bootstrapToolContributions` 通过
    /// `registerBuiltInTools(_:)` 注入 `ToolService` 的内置工具。传入后启动期校验
    /// 就会把"plugin 工具 + 内置工具 + sub-agent 工具"的并集一起查重，跨来源的
    /// 命名冲突在 boot 阶段就会以 `LumiToolRegistrationError` 抛出，调用方
    /// （通常是 `LumiCoreService` → `RootContainer`）用 `CrashedView` 优雅降级。
    ///
    /// - Parameters:
    ///   - dataRootDirectory: 数据根父目录（例如 `db_debug_v4/`），由 LumiAppKit 决定。
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - builtInTools: 内置工具列表（如 `ChatService.builtInTools`），默认为空。
    ///   - editorFactory: Editor 工厂闭包，接收 provider，返回具体的 `EditorService` 实例。
    public func boot<Service: AbstractEditorServicing>(
        dataRootDirectory: URL,
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool] = [],
        editorFactory: EditorBootstrapFactory<Service>?
    ) throws {
        projectState = ProjectState()
        layoutState = LumiLayoutState()

        // 物化 data root，并在其下创建 Core 子目录作为核心数据库的物理位置。
        // LumiCore 内部约定：core DB 始终位于 <dataRootDirectory>/Core/，调用方
        // 只需要提供 dataRootDirectory 本身。
        let standardizedRoot = dataRootDirectory.standardizedFileURL
        try FileManager.default.createDirectory(
            at: standardizedRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let coreDatabaseDirectory = standardizedRoot.appendingPathComponent("Core", isDirectory: true)
        try FileManager.default.createDirectory(
            at: coreDatabaseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        self.dataRootDirectory = standardizedRoot

        // 自动创建并注册 ChatService（喂 core 子目录）
        if let factory = chatServiceFactory {
            chatService = factory(coreDatabaseDirectory)
            registerService((any LumiChatServicing).self, chatService!)
            // ChatService 通常也实现 HistoryQueryService
            if let history = chatService as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }

        try bootstrapToolService(provider: provider, builtInTools: builtInTools)

        // 自动创建并注册 EditorService（仅当提供了 editorFactory）
        if let editorFactory {
            try bootstrapEditor(provider: provider, factory: editorFactory)
        }
    }
}

// MARK: - Plugin Path Helpers (nonisolated)

/// 当前活跃的 `LumiCore` 实例，供无法接收 `LumiPluginContext` 的静态代码（例如
/// `static let shared = XxxLocalStore()` 这类单例）解析存储路径。
///
/// 由 `LumiCoreService` 在 `init` 末尾、boot 完成后设置。应用同一时刻通常只有一个
/// `LumiCore` 实例在跑（参见 `final class` 文档中的"单实例 App，多实例单测"约定），
/// 所以这里的静态指针是安全的——它指向"当前活跃"那个实例，而不是一个独立的全局对象。
/// 仍然推荐在能拿到 `LumiPluginContext` 的地方用 `context.lumiCore`；`currentLumiCore`
/// 是给静态单例的兜底。
///
/// 之所以提到 `@MainActor` `LumiCore` 类外面做成模块级 `nonisolated`，是因为 plugin 侧
/// `static let shared = ...` 类的单例初始化往往发生在非 MainActor 上下文（例如 `actor`
/// 的 init、非 MainActor 的 `static let`），需要这个值 `nonisolated` 才能在那些上下文
/// 里读得到。`LumiCore` 上的同名 `current` 是给 MainActor 上下文的快速别名。
public nonisolated(unsafe) var currentLumiCore: (any LumiCoreAccessing)?

/// `currentLumiCore` 尚未被设置时（boot 之前/单测未注入）的 fallback 数据根路径。
///
/// 历史上 `AppConfig.getDBFolderURL()` 在未配置时退化为 `<AppSupport>/<bundleID>/`；
/// 这里保留同样的行为，让 plugin 在 `currentLumiCore` 为 nil 时仍能写到一个合理的
/// 目录，而不是 NPE / 写进 temp。
///
/// 同上，提到模块级 `nonisolated` 是为了让非 MainActor 上下文也能读得到。
public nonisolated(unsafe) var lumiCoreFallbackDataRootDirectory: URL = {
    let fileManager = FileManager.default
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
    return appSupport.appendingPathComponent(bundleID, isDirectory: true)
}()

/// `currentLumiCoreDataRootDirectory` 的 nonisolated 镜像。
///
/// 之所以单独维护一份：plugin 侧的 `static let shared = ...` 单例 init 经常发生在
/// 非 MainActor 上下文（actor init、非 MainActor `static let`），读 `currentLumiCore`
/// 是 nonisolated 的没问题，但顺着协议 `LumiCoreAccessing.dataRootDirectory` 走就会撞
/// 到 `@MainActor` 隔离。所以这里把 boot 后的 data root 缓存到模块级变量，
/// 由 `LumiCoreService` 在 `currentLumiCore` 写入后一并刷新。
///
/// 仍然是单一事实源（`LumiCore.dataRootDirectory`），这里只是它的 nonisolated 镜像。
public nonisolated(unsafe) var currentLumiCoreDataRootDirectory: URL?

/// `LumiCoreAccessing.pluginDataDirectory(for:)` 的 nonisolated 镜像。
///
/// 同上，plugin 单例 init 经常在非 MainActor 上下文，需要一个不走协议、纯 URL 计算的
/// 入口。`pluginName` 的清洗规则与 `LumiCore._sanitizeDirectoryName` 一致（字母数字保留，
/// 其余字符替换为 `_`），保证两条路径计算出同一个目录。
public nonisolated func lumiCorePluginDataDirectory(for pluginName: String) -> URL {
    let dataRoot = currentLumiCoreDataRootDirectory ?? lumiCoreFallbackDataRootDirectory
    let sanitized = pluginName
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: "_")
    let directoryName = sanitized.isEmpty ? "Plugin" : sanitized
    return dataRoot.appendingPathComponent(directoryName, isDirectory: true)
}
