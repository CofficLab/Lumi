import AgentToolKit
import Foundation

/// Agent 工具管理与执行能力（KernelCore 体系）。
///
/// 复刻自旧内核（KernelLumi）的 `ToolManaging`，供精简宿主（LumiMinimalApp 等）
/// 在 KernelCore 容器中以 Provider 形式使用。与旧版不同，本协议基于
/// `AgentToolKit` 的类型（`SuperAgentTool` / `ToolCall` / `ToolCallResult` /
/// `ToolArgument` / `CommandRiskLevel`），不依赖任何 KernelLumi 类型。
///
/// 合并了两类职责：
/// - 工具注册（插件通过 `add(_:pluginID:)` 贡献工具）
/// - 工具执行（Agent 循环通过 `execute(_:conversationID:turnID:)` 调用）
@MainActor
public protocol ToolManagerProviding: AnyObject {
    // MARK: - Registration（插件调用）

    /// 所有已注册的 Agent 工具，按注册顺序返回。
    func allTools() -> [any SuperAgentTool]

    /// 注册一个工具，并归属到指定插件（用于 UI 按插件分组展示）。
    func add(_ tool: any SuperAgentTool, pluginID: String)

    /// 按名称移除一个工具。
    func remove(id: String)

    /// 按注册它们的插件分组返回工具，组内保持注册顺序。
    /// 每项为 `(pluginID, tools)`；未指定插件归属的工具归入 `"Built-in"`。
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])]

    // MARK: - Execution（Agent 循环调用）

    /// 按名称查找工具。
    func tool(named name: String) -> (any SuperAgentTool)?

    /// 解析一次工具调用面向用户的展示描述。
    /// 工具或参数无法解析时返回 `nil`。
    func displayDescription(for toolCall: ToolCall) -> String?

    /// 评估一次工具调用的风险等级。
    /// 工具或参数无法解析时返回 `nil`，调用方应视为高风险处理。
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel?

    /// 执行一次工具调用并返回结果。
    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult

    // MARK: - Records（调用记录）

    /// 查询某个 AgentTurn 下全部已持久化的工具调用。
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord]

    /// 按原始 `ToolCall.id` 查询一次调用的结果。
    ///
    /// 调用未知、尚未完成或结果存储不可用时返回 `nil`。
    func toolCallResult(for toolCallID: String) async -> ToolCallResult?

    /// 删除某个会话的全部工具调用记录。
    ///
    /// 会话删除时调用，保证工具结果不会比引用它的会话时间线更长寿。
    func deleteToolCalls(for conversationID: UUID) async
}

// MARK: - Default registration

public extension ToolManagerProviding {
    /// 未指定插件归属的工具使用的默认分组。
    static var builtInPluginID: String { "Built-in" }

    /// 注册一个工具，不指定插件归属（归入 `"Built-in"` 分组）。
    func add(_ tool: any SuperAgentTool) {
        add(tool, pluginID: Self.builtInPluginID)
    }

    /// 移除全部已注册工具（插件启停、重建贡献时使用）。
    func removeAll() {
        for tool in allTools() {
            remove(id: tool.name)
        }
    }

    /// 向后兼容的执行入口：不携带 turnID。
    func execute(_ toolCall: ToolCall, conversationID: UUID) async -> ToolCallResult {
        await execute(toolCall, conversationID: conversationID, turnID: nil)
    }
}
