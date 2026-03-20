import Foundation

/// 负责“切换到某项目并更新系统提示词”的单一流程点。
@MainActor
final class ProjectSwitchHandler {
    private let projectVM: ProjectVM
    private let promptService: PromptService
    private let slashCommandService: SlashCommandService
    private let messageViewModel: MessagePendingVM

    init(
        projectVM: ProjectVM,
        promptService: PromptService,
        slashCommandService: SlashCommandService,
        messageViewModel: MessagePendingVM
    ) {
        self.projectVM = projectVM
        self.promptService = promptService
        self.slashCommandService = slashCommandService
        self.messageViewModel = messageViewModel
    }

    func handle(path: String) async {
        projectVM.switchProject(to: path)

        let languagePreference = projectVM.languagePreference
        let fullSystemPrompt = await promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )

        upsertSystemMessage(fullSystemPrompt)
        await slashCommandService.setCurrentProjectPath(path)

        let projectName = projectVM.currentProjectName
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)

        let switchMessage: String
        switch languagePreference {
        case .chinese:
            switchMessage = """
            ✅ 已切换到项目

            **项目名称**: \(projectName)
            **项目路径**: \(path)
            **使用模型**: \(config.model.isEmpty ? "默认" : config.model) (\(config.providerId))
            """
        case .english:
            switchMessage = """
            ✅ Switched to project

            **Project**: \(projectName)
            **Path**: \(path)
            **Model**: \(config.model.isEmpty ? "Default" : config.model) (\(config.providerId))
            """
        }

        messageViewModel.appendMessage(ChatMessage(role: .assistant, content: switchMessage))
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

