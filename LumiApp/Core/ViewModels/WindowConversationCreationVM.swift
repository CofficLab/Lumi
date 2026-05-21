import Foundation
import MagicKit

/// 窗口级会话创建 ViewModel
///
/// 由 `WindowScope` 持有，通过 `.environmentObject()` 注入。
/// 直接执行创建新会话的完整流程。
@MainActor
final class WindowConversationCreationVM: ObservableObject {
    private weak var scope: WindowScope?
    private let global: RootContainer

    init(scope: WindowScope, global: RootContainer) {
        self.scope = scope
        self.global = global
    }

    /// 创建新会话
    func createNewConversation() async {
        guard let scope else { return }

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
