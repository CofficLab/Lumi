import Foundation
import MagicKit

/// 获取当前会话 ID 工具
///
/// LLM 调用此工具获取当前选中的会话 ID。
/// 配合 `delay_message` 使用，确保延时消息发送到正确的会话。
///
/// ## 使用场景
///
/// LLM 需要在延时消息中指定目标会话时，先调用此工具获取 ID：
///
/// ```
/// 1. get_current_conversation() → { "conversation_id": "abc-123..." }
/// 2. delay_message(conversation_id="abc-123...", message="检查结果", seconds=5)
/// ```
struct GetCurrentConversationTool: SuperAgentTool {
    let name = "get_current_conversation"
    let description = "Get the current active conversation ID. Use this before calling delay_message to ensure the delayed message is sent to the correct conversation."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String]
        ]
    }

    init() {}

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let conversationId = await DelayMessageState.shared.getCurrentConversationId() else {
            let response: [String: Any] = [
                "error": "No conversation is currently selected."
            ]
            let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? "{\"error\": \"No conversation selected.\"}"
        }

        let response: [String: Any] = [
            "conversation_id": conversationId.uuidString
        ]
        let data = try JSONSerialization.data(withJSONObject: response, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{\"conversation_id\": \"\(conversationId.uuidString)\"}"
    }
}