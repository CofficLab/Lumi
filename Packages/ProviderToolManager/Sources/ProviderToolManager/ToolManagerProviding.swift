import KitAgentTool
import Foundation

private struct ToolInteractionPayload: Codable {
    let toolCallID: String
    let kind: String
    let question: String
    let options: [String]
    let mode: String

    enum CodingKeys: String, CodingKey {
        case toolCallID = "toolCallId"
        case kind, question, options, mode
    }
}

/// Agent 工具管理与执行能力。
@MainActor
public protocol ToolManagerProviding: AnyObject {
    /// 注册工具执行生命周期观察者。
    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle
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

    /// 用户授权后执行一个工具，并发布专用的授权完成事件。
    func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult

    /// 用户拒绝一个需要授权的工具调用，并发布专用的授权完成事件。
    func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult

    /// 将用户对工具交互的响应交回工具管理器。
    /// AgentLoop 不解析响应，也不决定是否执行工具。
    func resolveUserResponse(
        _ answer: String,
        for toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult

    /// 批量执行工具调用，内部处理授权判断。
    ///
    /// 按顺序逐个执行，根据 `policy` 决定每个工具是直接执行、拒绝还是标记为需要审批。
    /// 返回与输入 `toolCalls` 等长的 `[BatchToolResult]`，位置一一对应。
    ///
    /// - Parameters:
    ///   - toolCalls: 待执行的工具调用列表
    ///   - policy: 执行策略（由调用方从会话 automationLevel 映射）
    ///   - conversationID: 会话 ID
    ///   - turnID: 回合 ID（用于调用记录）
    /// - Returns: 与 `toolCalls` 等长的结果数组
    func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult]

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

    func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        guard case let .executed(result) = await executeBatch(
            [toolCall],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: turnID
        ).first else {
            return ToolCallResult(content: "Authorized tool execution returned no result.", isError: true)
        }
        return result
    }

    func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        guard case let .blocked(reason) = await executeBatch(
            [toolCall],
            policy: .blockAll,
            conversationID: conversationID,
            turnID: turnID
        ).first else {
            return ToolCallResult(content: "Tool execution was rejected by the user.", isError: true)
        }
        return ToolCallResult(content: reason, isError: true)
    }

    func resolveUserResponse(
        _ answer: String,
        for toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        if riskLevel(for: toolCall)?.requiresPermission == true {
            switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "允许", "同意", "是", "allow", "approve", "approved", "yes":
                return await execute(toolCall, conversationID: conversationID, turnID: turnID)
            default:
                return ToolCallResult(content: "User rejected the tool execution request.", isError: true)
            }
        }
        return ToolCallResult(content: answer)
    }

    /// 批量执行的默认实现：逐个调用 `execute`，根据 policy 做授权判断。
    func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult] {
        var results: [BatchToolResult] = []
        results.reserveCapacity(toolCalls.count)

        for toolCall in toolCalls {
            switch policy {
            case .blockAll:
                results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))

            case .autoExecute:
                let result = await execute(toolCall, conversationID: conversationID, turnID: turnID)
                results.append(.executed(result))

            case .requireApprovalForHighRisk:
                let riskLevel = self.riskLevel(for: toolCall) ?? .high
                if riskLevel.requiresPermission {
                    let operation = displayDescription(for: toolCall) ?? toolCall.name
                    let payload = ToolInteractionPayload(
                        toolCallID: "approval:\(toolCall.id)",
                        kind: "permission",
                        question: "此操作被判定为\(riskLevel.displayName)，是否允许执行？\n\(operation)",
                        options: ["允许", "拒绝"],
                        mode: "yes_no"
                    )
                    let content = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
                        ?? "Unable to create tool interaction request."
                    results.append(.needsUserResponse(payload: content))
                } else {
                    let result = await execute(toolCall, conversationID: conversationID, turnID: turnID)
                    results.append(.executed(result))
                }
            }
        }

        return results
    }
}
