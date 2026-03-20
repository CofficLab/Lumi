import Foundation

/// 负责“清空当前项目”的单一流程点。
@MainActor
final class ProjectClearHandler {
    private let conversationVM: ConversationVM
    private let projectVM: ProjectVM
    private let promptService: PromptService
    private let slashCommandService: SlashCommandService
    private let messageViewModel: MessagePendingVM

    init(
        conversationVM: ConversationVM,
        projectVM: ProjectVM,
        promptService: PromptService,
        slashCommandService: SlashCommandService,
        messageViewModel: MessagePendingVM
    ) {
        self.conversationVM = conversationVM
        self.projectVM = projectVM
        self.promptService = promptService
        self.slashCommandService = slashCommandService
        self.messageViewModel = messageViewModel
    }

    func handle() async {
        guard projectVM.isProjectSelected else { return }

        conversationVM.setSelectedConversation(nil)
        projectVM.clearProject()

        let languagePreference = projectVM.languagePreference
        let fullSystemPrompt = await promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )

        upsertSystemMessage(fullSystemPrompt)
        await slashCommandService.setCurrentProjectPath(nil)

        let clearMessage: String
        switch languagePreference {
        case .chinese:
            clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
        case .english:
            clearMessage = "✅ Project cleared. No project is currently selected."
        }

        messageViewModel.appendMessage(ChatMessage(role: .assistant, content: clearMessage))
    }

    private func upsertSystemMessage(_ content: String) {
        let currentMessages = messageViewModel.messages
        let systemMessage = ChatMessage(role: .system, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            messageViewModel.updateMessage(systemMessage, at: 0)
        } else {
            messageViewModel.insertMessage(systemMessage, at: 0)
        }
    }
}

