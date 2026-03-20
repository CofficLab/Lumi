import Foundation

/// 创建新会话的非 UI 业务流程（落库 + 切换队列 + 初始化系统/欢迎消息 + 通知）。
@MainActor
final class ConversationCreationHandler {
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

        // 1) 创建会话记录
        let conversation = chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        // 2) 切换消息发送队列到新会话
        messageSenderVM.switchToConversation(conversation.id)

        // 3) 生成系统上下文和欢迎消息（不阻塞 UI 选择）
        Task { [promptService, projectVM, conversationVM] in
            let systemMessage = await promptService.getSystemContextMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: projectVM.languagePreference
            )
            if !systemMessage.isEmpty {
                let msg = ChatMessage(role: .system, content: systemMessage)
                await conversationVM.saveMessage(msg, to: conversation.id)
            }

            let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: projectVM.languagePreference
            )
            if !welcomeMessage.isEmpty {
                let msg = ChatMessage(role: .assistant, content: welcomeMessage)
                await conversationVM.saveMessage(msg, to: conversation.id)
            }
        }

        // 4) 选中该会话
        conversationVM.setSelectedConversation(conversation.id)

        // 通知：Agent 模式新对话已创建（并已切换为选中会话）
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
    }
}

