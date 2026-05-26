import Foundation
import AgentToolKit

/// 创建新对话工具
///
/// 创建一个全新的对话会话，自动继承当前项目的模型偏好并注入欢迎消息。
struct CreateNewConversationTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "✨"
    nonisolated static let verbose: Bool = true
    let name = "create_new_conversation"

    /// 通过构造器注入的依赖
    private let conversationVM: WindowConversationVM
    private let projectName: String?
    private let projectPath: String?
    private let languagePreference: LanguagePreference

    init(
        conversationVM: WindowConversationVM,
        projectName: String?,
        projectPath: String?,
        languagePreference: LanguagePreference
    ) {
        self.conversationVM = conversationVM
        self.projectName = projectName
        self.projectPath = projectPath
        self.languagePreference = languagePreference
    }
    
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
            创建一个新的对话会话。

            参数（全部可选）：
            - title: 对话标题（可选，留空则使用默认标题）

            新对话会自动：
            - 继承当前项目的模型偏好（供应商/模型）
            - 自动选中并成为当前活跃对话
            - 注入欢迎消息
            - 关联当前选中的项目（如果有）
            """
        case .english:
            return """
            Create a new conversation session.

            Parameters (all optional):
            - title: Conversation title (optional, uses default if empty)

            The new conversation will automatically:
            - Inherit model preferences from the current project (provider/model)
            - Be selected and become the active conversation
            - Inject a welcome message
            - Associate with the current selected project (if any)
            """
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let titleDescription: String
        switch language {
        case .chinese:
            titleDescription = "对话标题（可选，留空则使用默认标题）"
        case .english:
            titleDescription = "Conversation title (optional, uses default if empty)"
        }
        return [
            "type": "object",
            "properties": [
                "title": [
                    "type": "string",
                    "description": titleDescription
                ]
            ],
            "required": [] as [String]
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        String(localized: "创建新对话", table: "ConversationList")
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 解析 title 参数
        let customTitle = arguments["title"]?.value as? String

        // 创建新对话（使用公共 API）
        await conversationVM.createNewConversation(
            projectName: projectName,
            projectPath: projectPath,
            languagePreference: languagePreference
        )

        // 如果提供了自定义标题，获取新创建的对话并设置标题
        if let title = customTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 在主线程上完成所有 Conversation 操作
            await MainActor.run {
                guard let conversationId = conversationVM.selectedConversationId,
                      let conversation = conversationVM.fetchConversation(id: conversationId) else {
                    return
                }
                conversationVM.updateConversationTitle(conversation, newTitle: trimmedTitle)
            }
        }

        // 获取创建结果
        let conversationId = await conversationVM.selectedConversationId

        guard let conversationId else {
            return """
            ## Create New Conversation

            **Status**: Failed to create conversation

            Please try again or check the application logs.
            """
        }

        let idShort = String(conversationId.uuidString.prefix(8))

        var result = """
        ## New Conversation Created ✅

        **Conversation ID**: `\(conversationId.uuidString)`
        **ID (short)**: `\(idShort)`
        """

        if let projectName {
            result += "\n**Project**: \(projectName)"
        }

        if let title = customTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result += "\n**Title**: \(title.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        result += """

        ---
        The new conversation is now active and ready to use.
        """

        return result
    }
}
