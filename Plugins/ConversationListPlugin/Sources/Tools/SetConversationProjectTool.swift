import Foundation
import SuperLogKit
import AgentToolKit
import LumiCoreKit

/// 设置对话关联项目工具
///
/// 为指定对话设置或解除项目关联。
public struct SetConversationProjectTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔗"
    public nonisolated static let verbose: Bool = false
    public let name = "set_conversation_project"

    /// 通过构造器注入的依赖
    private let conversationListContext: ConversationListContext

    public init(conversationListContext: ConversationListContext) {
        self.conversationListContext = conversationListContext
    }
    
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            为指定对话设置或解除项目关联。

            参数：
            - conversationId: 对话 ID（必填，完整的 UUID 字符串）
            - projectPath: 项目路径（可选，传入空字符串 "" 或 null 表示解除关联）

            设置关联后，该对话会出现在对应项目的历史记录中。
            """
        case .english:
            return """
            Set or remove the project association for a specified conversation.

            Parameters:
            - conversationId: Conversation ID (required, full UUID string)
            - projectPath: Project path (optional, pass "" or null to remove association)

            After setting, the conversation will appear in the project's history.
            """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let conversationIdDesc: String
        let projectPathDesc: String
        switch language {
        case .chinese:
            conversationIdDesc = "对话 ID（必填，完整的 UUID 字符串）"
            projectPathDesc = "项目路径（可选，传入空字符串或 null 表示解除关联）"
        case .english:
            conversationIdDesc = "Conversation ID (required, full UUID string)"
            projectPathDesc = "Project path (optional, pass empty string or null to remove association)"
        }
        return [
            "type": "object",
            "properties": [
                "conversationId": [
                    "type": "string",
                    "description": conversationIdDesc
                ],
                "projectPath": [
                    "type": "string",
                    "description": projectPathDesc
                ]
            ],
            "required": ["conversationId"]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let convId = (arguments["conversationId"]?.value as? String).map { String($0.prefix(8)) } ?? "unknown"
        return String(localized: "设置对话项目: \(convId)", bundle: .module)
    }
    
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 解析 conversationId 参数
        guard let conversationIdStr = arguments["conversationId"]?.value as? String,
              let conversationId = UUID(uuidString: conversationIdStr) else {
            return """
            ## Set Conversation Project ❌

            **Error**: Invalid or missing `conversationId` parameter.

            Please provide a valid UUID string.
            """
        }

        // 解析 projectPath 参数（null 或空字符串表示解除关联）
        let projectPath: String?
        if let pathArg = arguments["projectPath"]?.value as? String, !pathArg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            projectPath = pathArg.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            projectPath = nil
        }

        // 在主线程上完成所有 Conversation 操作
        let result = await MainActor.run { () -> (success: Bool, title: String?, oldProject: String?, newProject: String?) in
            guard let conversation = conversationListContext.fetchConversation(id: conversationId) else {
                return (false, nil, nil, nil)
            }

            let oldProject = conversation.projectPath
            conversationListContext.updateProjectAssociation(id: conversation.id, projectPath: projectPath)
            return (true, conversation.title, oldProject, projectPath)
        }

        guard result.success else {
            return """
            ## Set Conversation Project ❌

            **Error**: Conversation not found

            **Conversation ID**: `\(conversationIdStr)`

            Use `get_recent_conversations` to find a valid conversation ID.
            """
        }

        var response = "## Set Conversation Project ✅\n\n"
        response += "**Conversation**: \(result.title ?? "(unknown)")\n"
        response += "**ID**: `\(conversationIdStr)`\n\n"

        if let newProject = result.newProject {
            let projectName = URL(fileURLWithPath: newProject).lastPathComponent
            response += "**New Project**: \(projectName)"
        } else {
            response += "**New Project**: _None (association removed)_"
        }

        if let oldProject = result.oldProject {
            let oldProjectName = URL(fileURLWithPath: oldProject).lastPathComponent
            response += "\n**Previous Project**: \(oldProjectName)"
        } else {
            response += "\n**Previous Project**: _None_"
        }

        return response
    }
}
