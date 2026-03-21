import Foundation

/// 负责“创建新会话”的业务流程（落库会话 + 切换发送队列 + 初始化系统/欢迎消息）。
@MainActor
final class ConversationCreationVM: ObservableObject {
    private let promptService: PromptService
    private let chatHistoryService: ChatHistoryService
    private let messageSenderVM: MessageQueueVM
    private let conversationVM: ConversationVM
    private let projectVM: ProjectVM

    init(
        promptService: PromptService,
        chatHistoryService: ChatHistoryService,
        messageSenderVM: MessageQueueVM,
        conversationVM: ConversationVM,
        projectVM: ProjectVM
    ) {
        self.promptService = promptService
        self.chatHistoryService = chatHistoryService
        self.messageSenderVM = messageSenderVM
        self.conversationVM = conversationVM
        self.projectVM = projectVM
    }

    func createNewConversation() async {
        let projectId = projectVM.isProjectSelected ? projectVM.currentProjectPath : nil
        let projectName = projectVM.isProjectSelected ? projectVM.currentProjectName : nil
        let projectPath = projectVM.isProjectSelected ? projectVM.currentProjectPath : nil

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        messageSenderVM.switchToConversation(conversation.id)

        Task { [promptService, projectVM, conversationVM] in
            let systemMessage = await promptService.getSystemContextMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: projectVM.languagePreference
            )
            if !systemMessage.isEmpty {
                await conversationVM.saveMessage(ChatMessage(role: .system, content: systemMessage), to: conversation.id)
            }

            let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: projectVM.languagePreference
            )
            if !welcomeMessage.isEmpty {
                await conversationVM.saveMessage(ChatMessage(role: .assistant, content: welcomeMessage), to: conversation.id)
            }
        }

        conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
    }
}
