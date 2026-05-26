import Foundation
import AgentToolKit

/// 获取对话总数工具
///
/// 返回当前窗口中已保存的对话历史总数量。
struct GetConversationCountTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔢"
    nonisolated static let verbose: Bool = true
    let name = "get_conversation_count"

    /// 通过构造器注入的依赖
    private let conversationVM: WindowConversationVM

    init(conversationVM: WindowConversationVM) {
        self.conversationVM = conversationVM
    }
    
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取当前对话历史的总数量。返回会话总数，用于了解有多少个历史会话。"
        case .english:
            return "Get the total number of conversation histories. Returns the total count of conversations."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        String(localized: "获取对话总数", table: "ConversationList")
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        // 获取当前活跃窗口的项目路径（从 context 中获取）
        let projectPath = context.currentProjectPath

        // 通过注入的 conversationVM 获取所有对话（在主线程上执行）
        let totalCount: Int
        let projectCount: Int
        let projectName: String?

        (totalCount, projectCount, projectName) = await MainActor.run { () -> (Int, Int, String?) in
            let allConversations = conversationVM.fetchAllConversations()
            let totalCount = allConversations.count

            if let projectPath {
                let projectConversations = allConversations.filter { $0.projectId == projectPath }
                let projectCount = projectConversations.count
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                return (totalCount, projectCount, projectName)
            } else {
                return (totalCount, 0, nil)
            }
        }

        if let projectName {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)
            **Conversations for Current Project** (\(projectName)): \(projectCount)
            """
        } else {
            return """
            ## Conversation Count

            **Total Conversations**: \(totalCount)

            _No project currently selected._
            """
        }
    }
}
