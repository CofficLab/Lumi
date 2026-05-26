import Foundation
import AgentToolKit

/// 删除指定对话工具
///
/// 允许 AI 助手通过对话 ID 永久删除指定的对话会话及其所有消息。
struct DeleteConversationTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🗑️"
    nonisolated static let verbose: Bool = true
    let name = "delete_conversation"

    /// 通过构造器注入的依赖
    private let conversationVM: WindowConversationVM
    private let languagePreference: LanguagePreference

    init(conversationVM: WindowConversationVM, languagePreference: LanguagePreference) {
        self.conversationVM = conversationVM
        self.languagePreference = languagePreference
    }

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            删除指定的对话会话。此操作不可撤销，将永久移除该对话及其所有消息。

            参数：
            - conversationId: 要删除的对话 ID（UUID 字符串）

            注意：
            - 如果删除的是当前选中的对话，会自动清除选择状态
            - 删除操作不可撤销，请谨慎使用
            """
        case .english:
            return """
            Delete a specified conversation session. This action is irreversible and will permanently remove the conversation and all its messages.

            Parameters:
            - conversationId: The conversation ID to delete (UUID string)

            Notes:
            - If the deleted conversation is currently selected, the selection will be cleared
            - This action is irreversible, use with caution
            """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let idDescription: String
        switch language {
        case .chinese:
            idDescription = "要删除的对话 ID（UUID 字符串）"
        case .english:
            idDescription = "The conversation ID to delete (UUID string)"
        }
        return [
            "type": "object",
            "properties": [
                "conversationId": [
                    "type": "string",
                    "description": idDescription
                ]
            ],
            "required": ["conversationId"]
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let id = arguments["conversationId"]?.value as? String else {
            return String(localized: "删除对话", table: "ConversationList")
        }
        let shortId = String(id.prefix(8))
        return String(localized: "删除对话 \(shortId)", table: "ConversationList")
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        // 删除操作具有破坏性，属于中等风险
        .medium
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let idString = arguments["conversationId"]?.value as? String else {
            throw NSError(
                domain: "DeleteConversationTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'conversationId' argument"]
            )
        }

        guard let conversationId = UUID(uuidString: idString) else {
            return """
            ## Delete Conversation ❌

            **Status**: Invalid conversation ID

            The provided ID `\(idString)` is not a valid UUID format.

            Please check the ID and try again.
            """
        }

        // 在主线程上执行所有 Conversation 操作
        let result = await MainActor.run {
            guard let conversation = conversationVM.fetchConversation(id: conversationId) else {
                return """
                ## Delete Conversation ❌

                **Status**: Conversation not found

                No conversation exists with ID `\(idString)`.

                Use `get_recent_conversations` to list available conversations.
                """
            }

            let title = conversation.title
            let wasSelected = conversationVM.selectedConversationId == conversationId

            conversationVM.deleteConversation(conversation)

            var output = "## Conversation Deleted ✅\n\n"
            output += "**Title**: \(title.isEmpty ? "(untitled)" : title)\n"
            output += "**Conversation ID**: `\(idString)`\n"

            if wasSelected {
                output += "**Note**: This was the active conversation, selection has been cleared.\n"
            }

            return output
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)对话已删除：\(idString)")
        }

        return result
    }
}
