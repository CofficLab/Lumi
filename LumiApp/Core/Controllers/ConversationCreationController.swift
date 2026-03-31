import Foundation
import MagicKit

/// 处理「创建新会话」请求：落库会话、选中、首条 system / welcome 消息。
///
/// 由 `RootView` 注入 `RootViewContainer` 使用。
@MainActor
final class ConversationCreationController: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = true

    private let container: RootViewContainer

    init(container: RootViewContainer) {
        self.container = container
    }

    /// 执行创建流程（调用方需已 `consumePendingRequest`）
    func handlePendingRequest(requestId: UUID) async {
        let projectId = container.projectVM.isProjectSelected ? container.projectVM.currentProjectPath : nil
        let projectName = container.projectVM.isProjectSelected ? container.projectVM.currentProjectName : nil
        let projectPath = container.projectVM.isProjectSelected ? container.projectVM.currentProjectPath : nil
        let languagePreference = container.projectVM.languagePreference

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = container.chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        container.conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
        container.conversationCreationVM.completeRequest(id: requestId)

        let systemMessage = await container.promptService.getSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !systemMessage.isEmpty {
            container.conversationVM.saveMessage(
                ChatMessage(role: .system, conversationId: conversation.id, content: systemMessage),
                to: conversation.id
            )
        }

        let welcomeMessage = await container.promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !welcomeMessage.isEmpty {
            container.conversationVM.saveMessage(
                ChatMessage(role: .assistant, conversationId: conversation.id, content: welcomeMessage),
                to: conversation.id
            )
        }
    }
}
