import KitAgentTool
import Foundation

/// 工具执行策略。事件驱动的 ToolManager 插件负责从会话 automationLevel 映射。
///
/// 本类型不依赖 `ProviderConversation`，避免 ToolManager 包引入额外依赖。
/// ToolManager 插件负责从 `LumiAutomationLevel` 映射：
///
/// ```
/// .chat       → .blockAll
/// .autonomous → .autoExecute
/// .build      → .requireApprovalForHighRisk
/// ```
public enum ToolExecutionPolicy: Sendable, Equatable, CustomStringConvertible {
    /// 拒绝所有工具（chat 模式）。
    case blockAll
    /// 自动执行所有工具，不检查风险（autonomous 模式）。
    case autoExecute
    /// 低风险自动执行，高风险需要审批（build 模式）。
    case requireApprovalForHighRisk

    public var description: String {
        switch self {
        case .blockAll: return "blockAll"
        case .autoExecute: return "autoExecute"
        case .requireApprovalForHighRisk: return "requireApprovalForHighRisk"
        }
    }
}

/// 批量执行中单个工具调用的结果。
///
/// `executeBatch` 的返回元素。区分三种情况：
/// - `.executed` — 工具已执行（成功或失败），结果可直接落库
/// - `.blocked` — 工具被策略拒绝（chat 模式）
/// - `.needsUserResponse` — 工具需要用户响应；具体交互语义由交互请求内容决定
///
/// AgentLoop 只负责把需要用户响应的结果转换为通用挂起点。
public enum BatchToolResult: Sendable {
    /// 工具已执行。
    case executed(ToolCallResult)

    /// 工具被策略拒绝。
    case blocked(reason: String)

    /// 工具需要用户响应。payload 由工具管理器提供，AgentLoop 不解释其语义。
    case needsUserResponse(payload: String)
}
