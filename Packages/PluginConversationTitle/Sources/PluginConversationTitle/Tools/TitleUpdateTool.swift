import Foundation
import KitAgentTool
import LumiLoggingKit
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
        try await performUpdate(
            title: try validatedTitle(from: arguments),
            conversationID: nil
        )
    }

    /// 带执行上下文的执行入口。
    ///
    /// ## 为什么必须用 `context.conversationID` 而不是当前选中会话
    ///
    /// 工具在后台 detached Task 中执行（见 `ToolExecutionRuntime`），
    /// 期间用户完全可以切换当前选中的会话。若此时按「当前选中会话」写标题，
    /// A 会话的工具调用就会把标题写到 B 会话上——用户在列表里看到的正是
    /// 「某个对话的标题突然变成了另一个对话的标题」。
    ///
    /// `ToolExecutionContext.conversationID` 是宿主在提交工具时冻结下来的
    /// 会话 ID，与 UI 选中态无关，是这里唯一正确的写入目标。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let result = try await performUpdate(
            title: try validatedTitle(from: arguments),
            conversationID: context.conversationID
        )
        return ToolCallResult(content: result)
    }

    /// 校验并裁剪 `title` 参数；缺失或为空时抛 `ToolExecutionError`。
    private func validatedTitle(from arguments: [String: ToolArgument]) throws -> String {
        guard let title = (arguments["title"]?.value as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            Self.logger.error("\(Self.t)Conversation title tool called without a non-empty title argument")
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'title' argument"
            )
        }
        return title
    }

    /// 执行标题更新。
    ///
    /// - Parameters:
    ///   - title: 已裁剪的标题文本。
    ///   - conversationID: 目标会话 ID。传入时写该会话；为 nil 时退回
    ///     「当前选中会话」（仅供拿不到执行上下文的旧调用路径使用）。
    private func performUpdate(title: String, conversationID: UUID?) async throws -> String {
        // ConversationManaging 是 MainActor 隔离；工具本身是 Sendable，
        // 经 MainActor.run 跳回主线程访问。
        guard let conversations else {
            Self.logger.error("\(Self.t)Conversation title tool cannot update title because ConversationManaging is unavailable")
            return "## Update Conversation Title ❌\n\n**Status**: Conversation service unavailable."
        }

        let result = await MainActor.run {
            let targetID: UUID?
            if let conversationID {
                targetID = conversationID
            } else {
                targetID = conversations.selectedConversationID
            }
            guard let targetID else {
                Self.logger.error("\(Self.t)Conversation title tool cannot update title because no conversation is selected")
                return (updated: false, conversationID: nil as UUID?)
            }
            let updated = conversations.updateConversationTitle(title, for: targetID)
            if !updated {
                Self.logger.error("\(Self.t)Failed to update title for conversation \(targetID, privacy: .public)")
            }
            return (updated: updated, conversationID: targetID)
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
