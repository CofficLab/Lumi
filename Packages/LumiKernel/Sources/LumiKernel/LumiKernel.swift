import Foundation

/// Lumi 核心
///
/// 只持有协议类型，不依赖具体实现。
/// 所有具体实现通过插件注入。
@MainActor
public final class LumiKernel: ObservableObject {

    /// 服务注册表
    private var services: [ObjectIdentifier: Any] = [:]

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

    // MARK: - Service Registration

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

    // MARK: - Bootstrap

    /// 启动核心，从插件注入服务
    ///
    /// 此方法应该：
    /// 1. 发现所有插件
    /// 2. 调用插件的 provideServices()
    /// 3. 注册到服务表
    public func bootstrap(with providers: [any CoreServiceProvider]) async throws {
        for provider in providers {
            // 注册所有提供的服务
            if let storage = provider.storage {
                registerService(StorageProviding.self, storage)
            }
            if let project = provider.project {
                registerService(ProjectProviding.self, project)
            }
            if let layout = provider.layout {
                registerService(LayoutProviding.self, layout)
            }
            if let chat = provider.chat {
                registerService(ChatServiceProviding.self, chat)
            }
            if let editor = provider.editor {
                registerService(EditorServiceProviding.self, editor)
            }
            if let agentTool = provider.agentTool {
                registerService(AgentToolProviding.self, agentTool)
            }
        }
    }
}