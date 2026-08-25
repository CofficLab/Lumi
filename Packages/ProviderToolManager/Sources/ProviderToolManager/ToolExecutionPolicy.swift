import KitAgentTool
import Foundation

/// 工具执行策略（由调用方根据会话 automationLevel 映射后传入）。
///
/// 本类型不依赖 `ProviderConversation`，避免 ToolManager 包引入额外依赖。
/// 调用方（AgentLoop）负责从 `LumiAutomationLevel` 映射：
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
/// - `.needsApproval` — 工具需要用户审批（build 模式高风险）
///
/// AgentLoop 根据此枚举构造 `MessageToolResult` 和 `AgentLoopSuspension`。
public enum BatchToolResult: Sendable {
    /// 工具已执行。
    case executed(ToolCallResult)

    /// 工具被策略拒绝。
    case blocked(reason: String)

    /// 工具需要用户审批。
    ///
    /// AgentLoop 应据此构造 `AgentLoopSuspension(kind: "toolApproval")`
    /// 并返回 `awaitingUserResponse: true` 的结果给 LLM。
    case needsApproval(riskLevel: CommandRiskLevel)
}
