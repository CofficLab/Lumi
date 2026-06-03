import Foundation
import SuperLogKit
import AgentToolKit

/// 更新对话标题工具
///
/// 为指定对话设置自定义标题。
public struct UpdateConversationTitleTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = true
    public let name = "update_conversation_title"

    /// 通过构造器注入的依赖
    private let conversationVM: WindowConversationVM

    public init(conversationVM: WindowConversationVM) {
        self.conversationVM = conversationVM
    }
    
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            更新指定对话的标题。

            参数：
            - conversationId: 对话 ID（必填，完整的 UUID 字符串）
            - title: 新标题（必填）

            更新后，对话标题会立即生效并同步到对话列表。
            """
        case .english:
            return """
            Update the title of a specified conversation.

            Parameters:
            - conversationId: Conversation ID (required, full UUID string)
            - title: New title (required)

            The updated title takes effect immediately and syncs to the conversation list.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let conversationIdDesc: String
        let titleDesc: String
        switch language {
        case .chinese:
            conversationIdDesc = "对话 ID（必填，完整的 UUID 字符串）"
            titleDesc = "新标题（必填）"
        case .english:
            conversationIdDesc = "Conversation ID (required, full UUID string)"
            titleDesc = "New title (required)"
        }
        return [
            "type": "object",
            "properties": [
                "conversationId": [
                    "type": "string",
                    "description": conversationIdDesc
                ],
                "title": [
                    "type": "string",
                    "description": titleDesc
                ]
            ],
            "required": ["conversationId", "title"]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let title = (arguments["title"]?.value as? String).map { String($0.prefix(15)) } ?? "unknown"
        return String(localized: "更新对话标题: \(title)", bundle: .module)
    }
    
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 解析 conversationId 参数
        guard let conversationIdStr = arguments["conversationId"]?.value as? String,
              let conversationId = UUID(uuidString: conversationIdStr) else {
            return """
            ## Update Conversation Title ❌

            **Error**: Invalid or missing `conversationId` parameter.

            Please provide a valid UUID string.
            """
        }

        // 解析 title 参数
        guard let newTitle = arguments["title"]?.value as? String,
              !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return """
            ## Update Conversation Title ❌

            **Error**: Missing or empty `title` parameter.

            Please provide a non-empty title.
            """
        }

        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // 在主线程上完成所有 Conversation 操作
        let result = await MainActor.run { () -> (success: Bool, oldTitle: String?, newTitle: String) in
            guard let conversation = conversationVM.fetchConversation(id: conversationId) else {
                return (false, nil, trimmedTitle)
            }

            let oldTitle = conversation.title
            conversationVM.updateConversationTitle(conversation, newTitle: trimmedTitle)
            return (true, oldTitle, trimmedTitle)
        }

        guard result.success else {
            return """
            ## Update Conversation Title ❌

            **Error**: Conversation not found

            **Conversation ID**: `\(conversationIdStr)`

            Use `get_recent_conversations` to find a valid conversation ID.
            """
        }

        var response = "## Update Conversation Title ✅\n\n"
        response += "**Conversation ID**: `\(conversationIdStr)`\n"

        if let oldTitle = result.oldTitle {
            response += "**Previous Title**: \(oldTitle)\n"
        }

        response += "**New Title**: \(result.newTitle)"

        return response
    }
}
