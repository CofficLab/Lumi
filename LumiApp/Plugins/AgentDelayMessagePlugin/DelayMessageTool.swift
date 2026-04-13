import Foundation
import MagicKit

/// 延时消息工具
///
/// 在指定秒数后向目标会话注入一条用户消息，触发新一轮对话。
/// 等价于用户在延时结束后自己在输入框里敲了一句话。
///
/// ## 工作原理
///
/// 1. LLM 调用 `get_current_conversation()` 获取会话 ID
/// 2. LLM 调用 `delay_message(conversation_id, message, seconds)`
/// 3. 工具立即返回，当前回合正常结束
/// 4. 后台 Task sleep N 秒后，通过 `DelayMessageState` 持有的 messageQueueVM 引用入队消息
/// 5. RootView 检测到 queueVersion 变化，触发 attemptBeginNextQueuedSend()
/// 6. 新回合开始，LLM 收到这条用户消息并继续处理
///
/// ## 依赖
///
/// - `DelayMessageState`：@MainActor 单例，存储从 Environment 同步来的 VM 引用
/// - `MessageQueueVM`：消息入队，触发已有的发送闭环
/// - 不依赖 `RootViewContainer.shared`
struct DelayMessageTool: AgentTool, SuperLog {
    nonisolated static let emoji = "⏳"
    nonisolated static let verbose: Bool = false
    let name = "delay_message"
    let description = "Send a delayed user message to a conversation after a specified number of seconds. The current turn will end, and a new turn will start when the message arrives. Use get_current_conversation first to obtain the conversation ID."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "conversation_id": [
                    "type": "string",
                    "description": "The UUID of the target conversation. Obtain this from get_current_conversation."
                ],
                "message": [
                    "type": "string",
                    "description": "The message content to send after the delay. This will appear as a user message in the conversation."
                ],
                "seconds": [
                    "type": "number",
                    "description": "Number of seconds to wait before sending the message. Minimum 1, maximum 3600 (1 hour)."
                ]
            ],
            "required": ["conversation_id", "message", "seconds"]
        ]
    }

    init() {}

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 解析 conversation_id
        guard let conversationIdString = arguments["conversation_id"]?.value as? String,
              let conversationId = UUID(uuidString: conversationIdString) else {
            return "Error: invalid or missing 'conversation_id'. Use get_current_conversation to obtain a valid ID."
        }

        // 解析 message
        let message = (arguments["message"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !message.isEmpty else {
            return "Error: message cannot be empty."
        }

        // 解析 seconds
        var seconds = arguments["seconds"]?.value as? Double ?? 5.0
        seconds = max(1, min(3600, seconds))

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 延时 \(Int(seconds))s 后发送消息到会话 \(conversationId.uuidString.prefix(8))")
        }

        // 启动后台延时任务
        Task { [seconds, message, conversationId] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if Self.verbose {
                AppLogger.core.info("\(Self.t)⏰ 延时到达，注入消息：\(message.prefix(50))")
            }

            // 通过 DelayMessageState 持有的 VM 引用入队，在 MainActor 上执行
            await MainActor.run {
                DelayMessageState.shared.enqueueDelayedMessage(
                    conversationId: conversationId,
                    content: message
                )
            }
        }

        return "Scheduled: a message will be sent in \(Int(seconds)) seconds to conversation \(conversationId.uuidString.prefix(8)). The current turn will end now. When the message arrives, a new turn will start automatically."
    }
}