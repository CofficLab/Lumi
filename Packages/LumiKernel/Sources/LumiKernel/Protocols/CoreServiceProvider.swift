import Foundation

// MARK: - Core Service Provider

/// 核心服务提供者协议
///
/// 插件实现此协议来提供核心服务实现。
@MainActor
public protocol CoreServiceProvider: AnyObject {
    /// 提供存储服务
    var storage: (any StorageProviding)? { get }

    /// 提供项目管理服务
    var project: (any ProjectProviding)? { get }

    /// 提供布局服务
    var layout: (any LayoutProviding)? { get }

    /// 提供聊天服务
    var chat: (any ChatServiceProviding)? { get }

    /// 提供编辑器服务
    var editor: (any EditorServiceProviding)? { get }

    /// 提供 Agent 工具服务
    var agentTool: (any AgentToolProviding)? { get }
}

// MARK: - Default Implementation

/// 默认实现（所有服务可选）
extension CoreServiceProvider {
    public var storage: (any StorageProviding)? { nil }
    public var project: (any ProjectProviding)? { nil }
    public var layout: (any LayoutProviding)? { nil }
    public var chat: (any ChatServiceProviding)? { nil }
    public var editor: (any EditorServiceProviding)? { nil }
    public var agentTool: (any AgentToolProviding)? { nil }
}