import Foundation
import AgentToolKit

// MARK: - Agent Tools Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供 Agent 工具
    @MainActor public func agentTools(context: ToolContext) -> [SuperAgentTool] { [] }

    /// 默认实现：不提供内核级子 Agent 定义
    @MainActor public func subAgentDefinitions() -> [any SubAgentDefinitionProtocol] { [] }

    /// 默认实现：不提供发送中间件
    @MainActor public func sendMiddlewares() -> [AnySuperSendMiddleware] { [] }

    /// 默认实现：不提供 LLM 供应商类型
    nonisolated public func llmProviderType() -> (any SuperLLMProvider.Type)? { nil }

    /// 默认实现：不提供消息渲染器
    @MainActor public func messageRenderers() -> [any SuperMessageRenderer] { [] }
}
