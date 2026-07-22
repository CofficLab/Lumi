import Combine
import Foundation
import LumiKernel
import SwiftUI

/// LumiCore 业务核心
///
/// 旧 LumiAppKit/LumiCoreKit 体系中 `LumiCore` 类的等价实现,迁入 LumiFactory。
/// 持有所有核心业务组件(Storage / Project / Layout / Logo / AgentTool / ChatService / EditorService),
/// 实现 `LumiCoreProviding` 协议供 LumiKernel 通过 `lumiCore` 服务访问。
///
/// 重命名为 `LumiCoreConcrete` 以避免与 `LumiCoreProviding` typealias 冲突。
@MainActor
public final class LumiCoreConcrete: ObservableObject, LumiCoreProviding {
    public nonisolated(unsafe) static var current: (any LumiCoreAccessing)?

    public let projectComponent: ProjectComponent
    public let layoutComponent: LayoutComponent
    public let logoComponent: LogoComponent
    public let storage: StorageComponent
    public let agentToolComponent: AgentToolComponent
    public let chatService: any ObservableObject
    public var editorService: (any AbstractEditorServicing)?

    public var chatServiceTyped: (any LumiChatServicing) {
        chatService as! any LumiChatServicing
    }

    /// 工作区状态服务（rail/chat/content/panel 可见性）
    public var workspaceState: (any WorkspaceStateProviding)? {
        resolveService(WorkspaceStateProviding.self)
    }

    /// Panel Chrome 可见性，优先从 `WorkspaceState` 读取
    public var showsPanelChrome: Bool {
        workspaceState?.isPanelVisible ?? layoutComponent.state.showsPanelChrome
    }

    fileprivate var services: [ObjectIdentifier: Any] = [:]

    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance
    }

    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    public var currentProjectPath: String? {
        projectComponent.currentProject?.path
    }

    public init(
        dataRootDirectory: URL,
        provider: any LumiPluginToolManaging,
        builtInTools: [any LumiAgentTool] = [],
        agentToolComponent: AgentToolComponent,
        chatServiceFactory: @MainActor (URL) throws -> any ObservableObject,
        editorFactory: (@MainActor (any LumiPluginToolManaging) throws -> any AbstractEditorServicing)? = nil
    ) throws {
        self.projectComponent = ProjectComponent()
        self.layoutComponent = LayoutComponent()
        self.logoComponent = LogoComponent()
        self.agentToolComponent = agentToolComponent

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
        self.storage = StorageComponent(dataRootDirectory: standardizedRoot)

        let chatService = try chatServiceFactory(coreDatabaseDirectory)
        self.chatService = chatService
        if let chatServiceTyped = chatService as? any LumiChatServicing {
            registerService((any LumiChatServicing).self, chatServiceTyped)
            if let history = chatServiceTyped as? any HistoryQueryService {
                registerService((any HistoryQueryService).self, history)
            }
        }

        if let editorFactory {
            editorService = try editorFactory(provider)
            if let editorService {
                registerService((any AbstractEditorServicing).self, editorService)
            }
        }

        registerService((any LumiPluginToolManaging).self, provider)
    }
}

// MARK: - 兼容 typealias

/// 兼容旧 API - 旧代码用 `LumiCore` 指代具体类。
public typealias LumiCore = LumiCoreConcrete

// MARK: - LumiCore.ChatServiceFactory type alias

extension LumiCoreConcrete {
    public typealias ChatServiceFactory = @MainActor (URL) throws -> any ObservableObject
}
