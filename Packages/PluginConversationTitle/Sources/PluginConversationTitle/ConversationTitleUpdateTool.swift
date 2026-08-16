import Foundation
import AgentToolKit
import ProviderConversation

/// 标题更新 Agent 工具：让 LLM 可主动更新当前会话标题。
///
/// 复刻自旧版 `ConversationTitleUpdateTool`，适配新版 `SuperAgentTool` 协议。
public struct ConversationTitleUpdateTool: SuperAgentTool, @unchecked Sendable {
    /// 保持旧版工具名。
    public static let toolName = "update_conversation_title"

    public let name: String = Self.toolName

    private let conversations: (any ConversationManaging)?

    public init(conversations: (any ConversationManaging)? = nil) {
        self.conversations = conversations
    }

    public func description(for language: LanguagePreference) -> String {
        "Update the current conversation title."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": "A concise, descriptive title for the current conversation",
                ],
            ],
            "required": ["title"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let title = (arguments["title"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return "Update conversation title"
        }
        return "Update conversation title to \"\(title)\""
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let title = (arguments["title"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'title' argument"
            )
        }
        // ConversationManaging 是 MainActor 隔离；工具本身是 Sendable，
        // 经 MainActor.run 跳回主线程访问。
        guard let conversations else {
            return "## Update Conversation Title ❌\n\n**Status**: Conversation service unavailable."
        }

        let result = await MainActor.run {
            guard let conversationID = conversations.selectedConversationID else {
                return (updated: false, conversationID: nil as UUID?)
            }
            let updated = conversations.updateConversationTitle(title, for: conversationID)
            return (updated: updated, conversationID: conversationID)
        }

        guard result.updated, let conversationID = result.conversationID else {
            return "## Update Conversation Title ❌\n\n**Status**: Conversation not found or title update failed."
        }
        return """
        ## Conversation Title Updated ✅

        **Conversation ID**: `\(conversationID.uuidString)`
        **Title**: \(title)
        """
    }
}
