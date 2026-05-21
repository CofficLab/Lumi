import Foundation
import MagicKit

/// 会话控制器
///
/// 每个窗口拥有独立的 ConversationController 实例，通过 WindowScope 直接访问窗口级 VM。
@MainActor
final class ConversationController: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose: Bool = false

    private let scope: WindowScope
    private let global: RootContainer

    init(scope: WindowScope, global: RootContainer) {
        self.scope = scope
        self.global = global
    }

    // MARK: - 创建会话

    func handleCreationRequest(requestId: UUID) async {
        let projectId = scope.projectVM.isProjectSelected ? scope.projectVM.currentProjectPath : nil
        let projectName = scope.projectVM.isProjectSelected ? scope.projectVM.currentProjectName : nil
        let projectPath = scope.projectVM.isProjectSelected ? scope.projectVM.currentProjectPath : nil
        let languagePreference = scope.projectVM.languagePreference

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = global.chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date()),
            chatMode: global.agentSessionConfig.chatMode.rawValue
        )

        scope.conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
        scope.conversationCreationVM.completeRequest(id: requestId)

        let systemMessage = await global.promptService.getSystemContextMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !systemMessage.isEmpty {
            scope.conversationVM.saveMessage(
                ChatMessage(role: .system, conversationId: conversation.id, content: systemMessage),
                to: conversation.id
            )
        }

        let welcomeMessage = await global.promptService.getEmptySessionWelcomeMessage(
            projectName: projectName,
            projectPath: projectPath,
            language: languagePreference
        )
        if !welcomeMessage.isEmpty {
            scope.conversationVM.saveMessage(
                ChatMessage(role: .assistant, conversationId: conversation.id, content: welcomeMessage),
                to: conversation.id
            )
        }
    }
}
