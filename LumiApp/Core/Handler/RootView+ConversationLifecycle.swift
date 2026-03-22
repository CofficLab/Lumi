import SwiftUI

extension RootView {
    func loadConversation() {
        guard let conversationId = container.conversationVM.selectedConversationId else { return }
        Task { await handleConversationChanged(conversationId: conversationId, applyProjectContext: false) }
    }

    func onConversationChanged() {
        guard let conversationId = container.conversationVM.selectedConversationId else { return }
        Task { await handleConversationChanged(conversationId: conversationId, applyProjectContext: true) }
    }

    private func handleConversationChanged(conversationId: UUID, applyProjectContext: Bool) async {
        let snapshot = container.conversationRuntimeStore.agentRuntimeSnapshot(for: conversationId)

        container.thinkingStateViewModel.setActiveConversation(conversationId)
        container.thinkingStateViewModel.setIsThinking(snapshot.isThinking, for: conversationId)
        container.thinkingStateViewModel.setThinkingText(snapshot.thinkingText, for: conversationId)

        container.permissionRequestViewModel.setPendingPermissionRequest(snapshot.pendingPermissionRequest)
        container.depthWarningViewModel.setDepthWarning(snapshot.depthWarning)

        guard applyProjectContext else { return }
        guard let conversation = container.conversationVM.fetchConversation(id: conversationId) else { return }

        let path = conversation.projectId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let languagePreference = container.ProjectVM.languagePreference

        if let path, !path.isEmpty {
            container.ProjectVM.switchProject(to: path)
            await applyConversationProjectContext(path: path, languagePreference: languagePreference)
        } else {
            container.ProjectVM.clearProject()
            await applyConversationProjectContext(path: nil, languagePreference: languagePreference)
        }
    }

    private func applyConversationProjectContext(path: String?, languagePreference: LanguagePreference) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }
}
