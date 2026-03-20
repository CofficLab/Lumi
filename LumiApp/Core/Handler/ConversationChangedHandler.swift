import Foundation

/// 处理“会话选择变更”的单一流程点：
/// - 切换发送队列到对应会话
/// - 投影该会话 runtime snapshot 到各 UI ViewModel
/// - 可选：根据会话关联的项目，应用系统提示词与 slash command 的当前项目路径
@MainActor
final class ConversationChangedHandler {
    private let runtimeStore: ConversationRuntimeStore
    private let conversationVM: ConversationVM
    private let messageSenderVM: MessageQueueVM
    private let projectVM: ProjectVM
    private let promptService: PromptService
    private let slashCommandService: SlashCommandService
    private let messageViewModel: MessagePendingVM

    private let processingStateViewModel: ProcessingStateVM
    private let thinkingStateViewModel: ThinkingStateVM
    private let permissionRequestViewModel: PermissionRequestVM
    private let depthWarningViewModel: DepthWarningVM

    init(
        runtimeStore: ConversationRuntimeStore,
        conversationVM: ConversationVM,
        messageSenderVM: MessageQueueVM,
        projectVM: ProjectVM,
        promptService: PromptService,
        slashCommandService: SlashCommandService,
        messageViewModel: MessagePendingVM,
        processingStateViewModel: ProcessingStateVM,
        thinkingStateViewModel: ThinkingStateVM,
        permissionRequestViewModel: PermissionRequestVM,
        depthWarningViewModel: DepthWarningVM
    ) {
        self.runtimeStore = runtimeStore
        self.conversationVM = conversationVM
        self.messageSenderVM = messageSenderVM
        self.projectVM = projectVM
        self.promptService = promptService
        self.slashCommandService = slashCommandService
        self.messageViewModel = messageViewModel
        self.processingStateViewModel = processingStateViewModel
        self.thinkingStateViewModel = thinkingStateViewModel
        self.permissionRequestViewModel = permissionRequestViewModel
        self.depthWarningViewModel = depthWarningViewModel
    }

    func handle(conversationId: UUID, applyProjectContext: Bool) async {
        // 1) 切换消息发送队列
        _ = messageSenderVM.switchToConversation(conversationId)

        // 2) 投影 runtime snapshot -> UI ViewModel
        let snapshot = runtimeStore.agentRuntimeSnapshot(for: conversationId)
        processingStateViewModel.setIsProcessing(snapshot.isProcessing)
        processingStateViewModel.setLastHeartbeatTime(snapshot.lastHeartbeatTime)

        thinkingStateViewModel.setActiveConversation(conversationId)
        thinkingStateViewModel.setIsThinking(snapshot.isThinking, for: conversationId)
        thinkingStateViewModel.setThinkingText(snapshot.thinkingText, for: conversationId)

        permissionRequestViewModel.setPendingPermissionRequest(snapshot.pendingPermissionRequest)
        depthWarningViewModel.setDepthWarning(snapshot.depthWarning)

        // 3) 可选：应用项目上下文与 system prompt
        guard applyProjectContext else { return }

        guard let conversation = conversationVM.fetchConversation(id: conversationId) else { return }
        let path = conversation.projectId?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let path, !path.isEmpty {
            projectVM.switchProject(to: path)
            let languagePreference = projectVM.languagePreference
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )
            upsertSystemMessage(fullSystemPrompt)
            await slashCommandService.setCurrentProjectPath(path)
        } else {
            projectVM.clearProject()
            let languagePreference = projectVM.languagePreference
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )
            upsertSystemMessage(fullSystemPrompt)
            await slashCommandService.setCurrentProjectPath(nil)
        }
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

