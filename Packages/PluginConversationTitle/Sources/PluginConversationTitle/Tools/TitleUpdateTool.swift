import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderConversation

/// 标题更新 Agent 工具：让 LLM 可主动更新当前会话标题。
///
public struct TitleUpdateTool: SuperAgentTool, SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-title", category: "ConversationTitleUpdateTool")

    /// Agent 调用的工具名。
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
            Self.logger.error("\(Self.t)Conversation title tool called without a non-empty title argument")
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'title' argument"
            )
        }
        // ConversationManaging 是 MainActor 隔离；工具本身是 Sendable，
        // 经 MainActor.run 跳回主线程访问。
        guard let conversations else {
            Self.logger.error("\(Self.t)Conversation title tool cannot update title because ConversationManaging is unavailable")
            return "## Update Conversation Title ❌\n\n**Status**: Conversation service unavailable."
        }

        let result = await MainActor.run {
            guard let conversationID = conversations.selectedConversationID else {
                Self.logger.error("\(Self.t)Conversation title tool cannot update title because no conversation is selected")
                return (updated: false, conversationID: nil as UUID?)
            }
            let updated = conversations.updateConversationTitle(title, for: conversationID)
            if !updated {
                Self.logger.error("\(Self.t)Failed to update title for conversation \(conversationID, privacy: .public)")
            }
            return (updated: updated, conversationID: conversationID)
        }

        guard result.updated, let conversationID = result.conversationID else {
            Self.logger.error("\(Self.t)Conversation title update did not produce a successful conversation ID")
            return "## Update Conversation Title ❌\n\n**Status**: Conversation not found or title update failed."
        }
        return """
        ## Conversation Title Updated ✅

        **Conversation ID**: `\(conversationID.uuidString)`
        **Title**: \(title)
        """
    }
}

// Compatibility name retained for callers that still use the pre-refactor tool name.
public typealias ConversationTitleUpdateTool = TitleUpdateTool
