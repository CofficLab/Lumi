import SwiftUI

extension RootView {
    func onInitialConversationLoaded() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }
        Task { await handleConversationChanged(conversationId: conversationId, applyProjectContext: false) }
    }

    func onConversationSelectionChanged() {
        guard let conversationId = container.ConversationVM.selectedConversationId else { return }
        Task { await handleConversationChanged(conversationId: conversationId, applyProjectContext: true) }
    }

    @MainActor
    private func handleConversationChanged(conversationId: UUID, applyProjectContext: Bool) async {
        _ = container.MessageSenderVM.switchToConversation(conversationId)

        let snapshot = container.conversationRuntimeStore.agentRuntimeSnapshot(for: conversationId)
        container.processingStateViewModel.setIsProcessing(snapshot.isProcessing)
        container.processingStateViewModel.setLastHeartbeatTime(snapshot.lastHeartbeatTime)

        container.thinkingStateViewModel.setActiveConversation(conversationId)
        container.thinkingStateViewModel.setIsThinking(snapshot.isThinking, for: conversationId)
        container.thinkingStateViewModel.setThinkingText(snapshot.thinkingText, for: conversationId)

        container.permissionRequestViewModel.setPendingPermissionRequest(snapshot.pendingPermissionRequest)
        container.depthWarningViewModel.setDepthWarning(snapshot.depthWarning)

        guard applyProjectContext else { return }
        guard let conversation = container.ConversationVM.fetchConversation(id: conversationId) else { return }

        let path = conversation.projectId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let languagePreference = container.ProjectVM.languagePreference

        if let path, !path.isEmpty {
            container.ProjectVM.switchProject(to: path)
            let fullSystemPrompt = await container.promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )
            upsertConversationLifecycleSystemMessage(fullSystemPrompt)
            await container.slashCommandService.setCurrentProjectPath(path)
        } else {
            container.ProjectVM.clearProject()
            let fullSystemPrompt = await container.promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )
            upsertConversationLifecycleSystemMessage(fullSystemPrompt)
            await container.slashCommandService.setCurrentProjectPath(nil)
        }
    }

    private func upsertConversationLifecycleSystemMessage(_ content: String) {
        let currentMessages = container.messageViewModel.messages
        let systemMessage = ChatMessage(role: .system, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            container.messageViewModel.updateMessage(systemMessage, at: 0)
        } else {
            container.messageViewModel.insertMessage(systemMessage, at: 0)
        }
    }
}
