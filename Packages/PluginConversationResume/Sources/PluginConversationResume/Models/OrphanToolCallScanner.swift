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
    /// - Note: assistant 嵌套的 `toolCall.result` 只是展示快照，**不**算
    ///   协议配对（#633）。生产路径先写嵌套快照、再插独立 tool 消息，
    ///   两步之间崩溃时真实结果只存在于快照里；协议历史不会从快照生成
    ///   tool 消息，跳过修复等于把真实结果丢掉。
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

    /// 为一个孤儿 tool_call 生成修复用的 tool result 消息。
    ///
    /// 嵌套快照里已保存真实结果时（崩溃发生在「写快照」与「插独立消息」
    /// 之间，#633），用真实结果重建协议消息，而不是伪造「结果未知」——
    /// 否则模型看不到已完成的输出，可能重复执行副作用。
    /// 等待用户输入的快照不是真实结果，仍补占位。
    static func placeholderMessage(
        for orphan: OrphanToolCall,
        conversationID: UUID,
        createdAt: Date = Date()
    ) -> Message {
        if let result = orphan.toolCall.result, !result.awaitingUserResponse {
            return Message(
                conversationID: conversationID,
                role: .tool,
                content: result.content,
                createdAt: createdAt,
                turnID: orphan.turnID,
                isError: result.isError,
                toolCallID: orphan.toolCall.id
            )
        }
        return Message(
            conversationID: conversationID,
            role: .tool,
            content: placeholderContent,
            createdAt: createdAt,
            turnID: orphan.turnID,
            isError: true,
            toolCallID: orphan.toolCall.id
        )
    }

    /// 为所有孤儿 tool_call 生成占位消息。
    ///
    /// 占位消息的时间戳锚定在所属 assistant 消息（及其已有工具结果）之后、
    /// 下一条消息之前，而不是按当前时间追加到历史末尾（#636）。否则
    /// `assistant(tool_use) → user → tool_result` 的顺序会被 Anthropic
    /// 端点以 400 拒绝——tool_result 必须紧跟它的 tool_use。
    static func placeholderMessages(
        for orphans: [OrphanToolCall],
        in history: [Message],
        conversationID: UUID
    ) -> [Message] {
        orphans.map { orphan in
            placeholderMessage(
                for: orphan,
                conversationID: conversationID,
                createdAt: insertionDate(for: orphan, in: history)
            )
        }
    }

    /// 计算占位消息的插入时间：取「锚点消息」与「下一条消息」的中点。
    ///
    /// 锚点是所属 assistant 消息本身，或紧随其后、属于同一 assistant 的
    /// 最后一条已有 tool result。历史末尾没有下一条消息时按当前时间追加。
    private static func insertionDate(
        for orphan: OrphanToolCall,
        in history: [Message]
    ) -> Date {
        guard let assistantIndex = history.firstIndex(where: { $0.id == orphan.assistantMessageID }) else {
            return Date()
        }
        let assistant = history[assistantIndex]
        let ownCallIDs = Set(assistant.toolCalls?.map(\.id) ?? [])
        var anchorIndex = assistantIndex
        var scanIndex = assistantIndex + 1
        while scanIndex < history.count,
              history[scanIndex].role == .tool,
              history[scanIndex].turnID == assistant.turnID,
              let toolCallID = history[scanIndex].toolCallID,
              ownCallIDs.contains(toolCallID) {
            anchorIndex = scanIndex
            scanIndex += 1
        }
        let anchor = history[anchorIndex].createdAt
        guard scanIndex < history.count else { return Date() }
        let next = history[scanIndex].createdAt
        guard next > anchor else { return anchor }
        return anchor.addingTimeInterval(next.timeIntervalSince(anchor) / 2)
    }
}
