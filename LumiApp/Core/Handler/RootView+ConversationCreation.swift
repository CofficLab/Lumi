import Foundation

extension RootView {
    func onConversationCreationRequested() {
        guard let requestId = container.conversationCreationVM.pendingRequest?.id else { return }
        guard let request = container.conversationCreationVM.consumePendingRequest(id: requestId) else { return }

        Task { await createConversation(using: request) }
    }

    private func createConversation(using request: ConversationCreationVM.ConversationCreationRequest) async {
        let projectId = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectPath : nil
        let projectName = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectName : nil
        let projectPath = container.ProjectVM.isProjectSelected ? container.ProjectVM.currentProjectPath : nil
        let languagePreference = container.ProjectVM.languagePreference

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"

        let conversation = container.chatHistoryService.createConversation(
            projectId: projectId,
            title: "新会话 " + formatter.string(from: Date())
        )

        container.messageSenderVM.switchToConversation(conversation.id)
        container.conversationVM.setSelectedConversation(conversation.id)
        NotificationCenter.postAgentConversationCreated(conversationId: conversation.id)
        container.conversationCreationVM.completeRequest(id: request.id)

        Task {
            let systemMessage = await container.promptService.getSystemContextMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: languagePreference
            )
            if !systemMessage.isEmpty {
                await container.conversationVM.saveMessage(ChatMessage(role: .system, content: systemMessage), to: conversation.id)
            }

            let welcomeMessage = await container.promptService.getEmptySessionWelcomeMessage(
                projectName: projectName,
                projectPath: projectPath,
                language: languagePreference
            )
            if !welcomeMessage.isEmpty {
                await container.conversationVM.saveMessage(ChatMessage(role: .assistant, content: welcomeMessage), to: conversation.id)
            }
        }
    }
}
