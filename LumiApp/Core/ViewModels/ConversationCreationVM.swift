import Foundation

/// 仅负责“创建新会话”的业务流程（落库会话 + 切换发送队列 + 初始化系统/欢迎消息）。
@MainActor
final class ConversationCreationVM: ObservableObject {
    private let handler: ConversationCreationHandler

    init(
        promptService: PromptService,
        chatHistoryService: ChatHistoryService,
        messageSenderVM: MessageQueueVM,
        conversationVM: ConversationVM,
        projectVM: ProjectVM
    ) {
        self.handler = ConversationCreationHandler(
            promptService: promptService,
            chatHistoryService: chatHistoryService,
            messageSenderVM: messageSenderVM,
            conversationVM: conversationVM,
            projectVM: projectVM
        )
    }

    func createNewConversation() async {
        await handler.createNewConversation()
    }
}

