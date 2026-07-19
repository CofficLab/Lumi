import Combine
import Foundation
import LumiCoreChat
import LumiCoreLayout
import LumiCorePlugin
import SwiftUI

@MainActor
public final class LumiCore: LumiCoreAccessing, LumiCoreBootstrapping, ChatServiceDelegate {
    public nonisolated(unsafe) static var current: (any LumiCoreAccessing)?

    // MARK: - Components

    @Published public var projectComponent: ProjectComponent
    @Published public var layoutComponent: LayoutComponent
    @Published public var logoComponent: LogoComponent
    public let storage: StorageComponent
    public let agentToolComponent: AgentToolComponent

    public let chatService: any ObservableObject
    /// Typed accessor for chatService as LumiChatServicing
    public var chatServiceTyped: (any LumiChatServicing) {
        chatService as! any LumiChatServicing
    }
    public var editorService: (any AbstractEditorServicing)?
    private var services: [ObjectIdentifier: Any] = [:]

    // MARK: - ChatServiceDelegate

    public var currentProjectPath: String? {
        projectComponent.currentProject?.path
    }

    public var lumiCore: (any LumiCoreAccessing)? {
        self
    }

    // MARK: - Initialization

    /// 一次性初始化:接收所有依赖并完成全部字段绑定。
    public init(
        dataRootDirectory: URL,
        provider: any AgentToolProviding,
        builtInTools: [any LumiAgentTool] = [],
        agentToolComponent: AgentToolComponent,
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
        if let chatServiceTyped = chatService as? any LumiChatServicing {
            registerService((any LumiChatServicing).self, chatServiceTyped)
            if let history = chatServiceTyped as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }

        // 4. 可选:创建并注册 EditorService(不依赖 self)
        if let editorFactory {
            editorService = try editorFactory(provider)
            if let editorService {
                registerService((any AbstractEditorServicing).self, editorService)
            }
        }

        // 5. 初始化空壳 ToolService（启动期不收集任何工具）
        //    provider 注册进服务表：per-request 构建路径（AgentToolComponent.buildToolSet）
        //    会从服务表取 provider 来收集插件工具，从而让 LumiCoreKit 不必反向持有
        //    App 层的 PluginService。工具集完全由 buildToolSet 在每次发消息时按
        //    当前 context 构建，启动期零工具开销。
        registerService((any AgentToolProviding).self, provider)
        // TODO: implement bootstrapToolService if needed
        // agentToolComponent.bootstrapToolService(lumiCore: self)
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

}
