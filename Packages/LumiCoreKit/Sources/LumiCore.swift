import Combine
import Foundation
import SwiftUI

@MainActor
public final class LumiCore: LumiCoreAccessing, LumiCoreBootstrapping {
    // MARK: - Active Instance

    /// 当前活跃的 `LumiCore` 实例，供无法接收 `LumiPluginContext` 的静态代码（例如
    /// `static let shared = XxxLocalStore()` 这类单例）解析存储路径。
    ///
    /// 由 `RootContainer` 在 `init` 末尾、boot 完成后设置。应用同一时刻通常只有一个
    /// `LumiCore` 实例在跑（参见 `final class` 文档中的"单实例 App，多实例单测"约定），
    /// 所以静态指针在这里是安全的——它指向"当前活跃"那个实例，而不是一个独立的全局对象。
    /// 仍然推荐在能拿到 `LumiPluginContext` 的地方用 `context.lumiCore`；`current` 是
    /// 给静态单例的兜底。
    public nonisolated(unsafe) static var current: (any LumiCoreAccessing)?
    
    // MARK: - Components

    public let projectComponent: ProjectComponent
    public let layoutComponent: LayoutComponent
    public let storage: StorageComponent

    // MARK: - State

    public var logoRegistry: LogoRegistry { .shared }

    /// ChatService。init 时由 chatServiceFactory 创建(非可选)。
    /// 注意:工厂创建时 ChatService 的 lumiCore 引用先留空,由 RootContainer 在
    /// LumiCore 创建完成后调 `chatService.configure(lumiCore:)` 回填——这是 Swift
    /// 两阶段初始化约束下的延迟注入模式(见 ChatService.lumiCore 注释)。
    public let chatService: (any LumiChatServicing)

    /// 编辑器服务。init 时由调用方传入实例(具体类型的 `configure(lumiCore:)`
    /// 回填由 App 层在创建 LumiCore 之后调用,因为该方法是 EditorCoreService 的
    /// 具体方法、不在 `AbstractEditorServicing` 协议里,LumiCoreKit 无法直接调)。
    public var editorService: (any AbstractEditorServicing)?

    // MARK: - Internal Storage

    /// 内部服务注册表，用于 `makePluginContext` 自动注入依赖。
    private var services: [ObjectIdentifier: Any] = [:]

    /// 内部 `ObservableObject` 子状态（`projectComponent` / `layoutComponent`）的
    /// `objectWillChange` 转发订阅。把它们的变更信号桥接到 `LumiCore.objectWillChange`，
    /// 这样用 `@ObservedObject var lumiCore: LumiCore` 的 SwiftUI 视图（如 `AppLayoutView`）
    /// 才能在子状态变更时收到刷新信号——否则只观察 `LumiCore` 的 @Published 是收不到的
    /// （`@Published` 只会在引用本身重新赋值时 fire，子状态的属性变化不穿透）。
    ///
    /// 注意：`chatService` 类型是 `any LumiChatServicing`，存在类型的关联类型会被擦除成
    /// `any Publisher`，`sink` 不可用，因此暂不做转发。`chatService` 在视图层通常以
    /// `let` 注入（见 `AppLayoutView`），不通过 `@ObservedObject` 监听，所以不会触发
    /// "UI 不刷新" 的同款问题；需要时可在 `LumiChatServicing` 实现里手动 `objectWillChange.send()`。
    private var projectComponentSubscription: AnyCancellable?
    private var layoutComponentSubscription: AnyCancellable?

    /// 订阅具体类型的子 `ObservableObject`（`ProjectComponent` / `LumiLayoutState`）的
    /// `objectWillChange`，转发到本实例的 `objectWillChange`。
    private func subscribeToChild<T: ObservableObject>(
        _ child: T,
        into subscription: inout AnyCancellable?
    ) {
        subscription = child.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Initialization

    /// 一次性初始化:接收所有依赖并完成全部字段绑定。
    ///
    /// 取代旧的"空 init + setupChatService + boot"两阶段模式——所有字段在 init 结束时
    /// 即为非空就绪状态,调用方无需再写 `?.` 可选链。
    ///
    /// - Parameters:
    ///   - dataRootDirectory: 数据根父目录(例如 `db_debug_v4/`),由 LumiAppKit 决定。
    ///     LumiCore 在其下创建 `Core/` 子目录作为核心数据库物理位置。
    ///   - provider: Agent Tool 贡献者(通常是 `PluginService`)。
    ///   - builtInTools: 内置工具列表(如 `ChatService.builtInTools`),默认为空。
    ///     启动期校验会把"plugin 工具 + 内置工具 + sub-agent 工具"的并集一起查重。
    ///   - chatServiceFactory: ChatService 工厂闭包,接收 core 数据库目录,
    ///     返回 `any LumiChatServicing` 实例。工厂创建的 ChatService 的 lumiCore
    ///     引用应留空(nil),由调用方在 LumiCore 创建后调 `chatService.configure(lumiCore:)` 回填。
    ///   - editorFactory: 可选的 Editor 工厂闭包。传入时创建并注册 editorService;
    ///     不传则 editorService 为 nil(适用于不需要编辑器的场景)。
    public init(
        dataRootDirectory: URL,
        provider: any LumiAgentToolProviding,
        builtInTools: [any LumiAgentTool] = [],
        chatServiceFactory: @escaping ChatServiceFactory,
        editorFactory: (@MainActor (any LumiAgentToolProviding) throws -> any AbstractEditorServicing)? = nil
    ) throws {
        // 1. 自给组件(无外部依赖,直接创建)
        let projectComponent = ProjectComponent()
        self.projectComponent = projectComponent
        let layoutComponent = LayoutComponent()
        self.layoutComponent = layoutComponent

        // 2. 物化 data root,在其下创建 Core 子目录
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
        // 创建存储组件(持有 dataRootDirectory,后续 coreDataDirectory/pluginDataDirectory 转发到它)
        self.storage = StorageComponent(dataRootDirectory: standardizedRoot)

        // 3. 创建并注册 ChatService(不依赖 self:工厂传 nil lumiCore,稍后由调用方回填)
        let chatService = chatServiceFactory(coreDatabaseDirectory)
        self.chatService = chatService
        registerService((any LumiChatServicing).self, chatService)
        if let history = chatService as? any HistoryQueryService {
            registerService((any HistoryQueryService).self, history)
        }

        // 4. 可选:创建并注册 EditorService(不依赖 self)
        if let editorFactory {
            editorService = try editorFactory(provider)
            if let editorService {
                registerService((any AbstractEditorServicing).self, editorService)
            }
        }

        // 5. 初始化 ToolService + 启动期工具名校验
        try bootstrapToolService(provider: provider, builtInTools: builtInTools)

        // 6. 订阅子状态 objectWillChange 转发
        subscribeToChild(projectComponent, into: &projectComponentSubscription)
        subscribeToChild(layoutComponent, into: &layoutComponentSubscription)
    }

    // MARK: - Test-only injection

    #if DEBUG
        /// 仅 DEBUG 编译下可见的内部状态注入器,用于单元测试。
        /// 注意:本批测试改造在另一轮进行,这里暂时保留以兼容现有测试编译。
        internal func _testInject(projectComponent: ProjectComponent) {
            // 字段已改为非可选 let,这里仅作占位;测试重写时会移除本方法。
        }
    #endif

    // MARK: - Service Registry

    /// 注册一个服务实例，供 `makePluginContext` 自动注入依赖。
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
}
