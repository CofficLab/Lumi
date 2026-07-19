import Foundation
import LumiCoreAgentTool
import LumiCoreLayout
import LumiCorePlugin

// MARK: - ChatServiceDelegate

/// ChatService 的代理协议，用于解耦 ChatService 与 LumiCoreKit。
///
/// ChatService 通过此协议访问所需的核心功能，而不直接依赖 LumiCoreKit。
/// LumiCore 在创建 ChatService 后通过 `configure(delegate:)` 注入自身。
@MainActor
public protocol ChatServiceDelegate: AnyObject {
    /// Agent 工具功能组件。
    var agentToolComponent: AgentToolComponent { get }

    /// 当前项目路径（如果有的话）。
    var currentProjectPath: String? { get }

    /// LumiCore 访问入口，供 ChatService 在需要时直接访问内核能力。
    var lumiCore: (any LumiCoreAccessing)? { get }
}