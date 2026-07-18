import Combine
import Foundation
import SwiftUI

@MainActor
public final class LumiCore: LumiCoreAccessing, LumiCoreBootstrapping {
    public nonisolated(unsafe) static var current: (any LumiCoreAccessing)?

    // MARK: - Components

    public let projectComponent: ProjectComponent
    public let layoutComponent: LayoutComponent
    public let storage: StorageComponent
    public let logoComponent: LogoComponent
    public let agentToolComponent: AgentToolComponent

    public let chatService: (any LumiChatServicing)
    public var editorService: (any AbstractEditorServicing)?
    private var services: [ObjectIdentifier: Any] = [:]
    private var projectComponentSubscription: AnyCancellable?
    private var layoutComponentSubscription: AnyCancellable?
    private var logoComponentSubscription: AnyCancellable?

    /// 订阅具体类型的子 `ObservableObject`（`ProjectComponent` / `LayoutComponent` / `LogoComponent`）的
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
    public init(
        dataRootDirectory: URL,
        provider: any AgentToolProviding,
        builtInTools: [any LumiAgentTool] = [],
        chatServiceFactory: @escaping ChatServiceFactory,
        editorFactory: (@MainActor (any AgentToolProviding) throws -> any AbstractEditorServicing)? = nil
    ) throws {
        // 1. 自给组件(无外部依赖,直接创建)
        let projectComponent = ProjectComponent()
        self.projectComponent = projectComponent
        let layoutComponent = LayoutComponent()
        self.layoutComponent = layoutComponent
        let logoComponent = LogoComponent()
        self.logoComponent = logoComponent
        let agentToolComponent = AgentToolComponent()
        self.agentToolComponent = agentToolComponent

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
        let chatService = try chatServiceFactory(coreDatabaseDirectory)
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
        try agentToolComponent.bootstrapToolService(
            lumiCore: self,
            provider: provider,
            builtInTools: builtInTools
        )

        // 6. 订阅子状态 objectWillChange 转发
        subscribeToChild(projectComponent, into: &projectComponentSubscription)
        subscribeToChild(layoutComponent, into: &layoutComponentSubscription)
        subscribeToChild(logoComponent, into: &logoComponentSubscription)
    }

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
