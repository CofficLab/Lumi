import Foundation
import ProviderMessage

/// 找出消息历史中「没有对应 tool result」的 assistant 工具调用。
///
/// ## 为什么必须修复
///
/// 回合在工具执行途中被崩溃打断时，消息库里会留下
/// `assistant(toolCalls=[A, B])`，但 A、B 的 tool result 消息**不存在**。
///
/// 直接拿这段历史去请求 LLM，OpenAI / Anthropic 兼容端点会返回 400：
/// 「tool_use 找不到对应的 tool_result」。也就是说「继续」按钮点下去
/// 会立刻报错，恢复功能形同虚设。
///
/// 修复方式是在恢复前为每个孤儿 tool_call 补一条占位 tool result，
/// 让协议重新配对。
struct OrphanToolCall {
    /// 所属 assistant 消息 ID。
    let assistantMessageID: UUID
    /// 孤儿工具调用。
    let toolCall: MessageToolCall
    /// 该助手消息所属的回合 ID。
    let turnID: UUID?
}

/// 孤儿工具调用扫描器。
enum OrphanToolCallScanner {
    /// 找出所有缺少 tool result 的工具调用。
    ///
    /// 判定口径与 `AgentLoopManager.incompleteToolCallMessage` 对齐：
    /// 一个 tool_call 算「已配对」的条件是存在同 `turnID` 的 `role == .tool`
    /// 且 `toolCallID` 匹配的消息。
    ///
    /// - Note: 跨回合配对是**不**接受的。同一个 tool_call ID 在不同回合
    ///   重复出现是合法的（模型可以复用 ID），把 A 回合的 tool result 拿来
    ///   配 B 回合的 tool_call 会掩盖真正缺失的那一个。
    ///
    /// - Parameter messages: 会话消息历史（按时间升序）。
    static func scan(_ messages: [Message]) -> [OrphanToolCall] {
        // tool_call_id -> 已配对的回合集合
        var pairedTurnIDsByToolCallID: [String: Set<UUID?>] = [:]
        for message in messages where message.role == .tool {
            guard let toolCallID = message.toolCallID else { continue }
            pairedTurnIDsByToolCallID[toolCallID, default: []].insert(message.turnID)
        }

        var orphans: [OrphanToolCall] = []
        for message in messages where message.role == .assistant {
            guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { continue }
            for toolCall in toolCalls {
                // 展示快照里已有结果，说明这条调用已经完成。
                guard toolCall.result == nil else { continue }
                let pairedTurns = pairedTurnIDsByToolCallID[toolCall.id] ?? []
                if pairedTurns.contains(message.turnID) { continue }
                orphans.append(
                    OrphanToolCall(
                        assistantMessageID: message.id,
                        toolCall: toolCall,
                        turnID: message.turnID
                    )
                )
            }
        }
        return orphans
    }
}

/// 为孤儿 tool_call 生成占位 tool result 消息。
enum OrphanToolCallRepair {
    /// 占位结果的正文。
    ///
    /// 明确告诉模型「这个工具的结果未知」，而不是伪造一个看似正常的输出。
    /// 模型据此可以自行决定：重新执行、换个思路，或向用户说明。
    static let placeholderContent = """
    [interrupted] The tool call did not complete because the application was \
    interrupted before the tool returned a result. Its actual outcome is unknown.
    """

    /// 为一个孤儿 tool_call 生成占位 tool result 消息。
    static func placeholderMessage(
        for orphan: OrphanToolCall,
        conversationID: UUID
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .tool,
            content: placeholderContent,
            turnID: orphan.turnID,
            isError: true,
            toolCallID: orphan.toolCall.id
        )
    }

    /// 为所有孤儿 tool_call 生成占位消息。
    static func placeholderMessages(
        for orphans: [OrphanToolCall],
        conversationID: UUID
    ) -> [Message] {
        orphans.map { placeholderMessage(for: $0, conversationID: conversationID) }
    }
}
