import Foundation
import AgentToolKit
import os

/// 获取对话总数工具
///
/// 返回当前窗口中已保存的对话历史总数量。
struct GetConversationCountTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔢"
    nonisolated static let verbose: Bool = true
    let name = "get_conversation_count"
    
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
        // 从 ToolContext 获取当前窗口的 conversationVM
        guard let conversationVM = context.conversationVM else {
            return """
            ## Conversation Count

            **Status**: No active window

            Please ensure a window is open.
            """
        }

        // 获取当前活跃窗口的项目路径
        let projectPath = await MainActor.run {
            RootContainer.shared.windowManagerVM.activeWindowContainer?.projectPath
        }

        // 通过 conversationVM 获取所有对话
        let allConversations = await MainActor.run {
            conversationVM.fetchAllConversations()
        }

        let totalCount = allConversations.count

        if let projectPath {
            // 按项目过滤统计（可选信息）
            let projectConversations = allConversations.filter { $0.projectId == projectPath }
            let projectCount = projectConversations.count
            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent

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
