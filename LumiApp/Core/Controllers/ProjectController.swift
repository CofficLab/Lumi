import Foundation
import MagicKit

/// 项目上下文与 Root 系统提示词联动
@MainActor
final class ProjectController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = true
    private let container: RootViewContainer

    init(container: RootViewContainer) {
        self.container = container
    }

    /// 从偏好恢复上次选中的项目路径
    func applySavedProjectFromPreferences() {
       
    }

    /// 响应 `ProjectContextRequestVM` 的请求
    func handleProjectContextRequest(_ request: ProjectContextRequest) async {
        switch request {
        case let .switchProject(path):
            await handleProjectSwitch(path: path)
        case .clearProject:
            await handleProjectClear()
        }
    }

    // MARK: - Private

    private func applyConversationProjectContext(path: String?) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }

    private func handleProjectSwitch(path: String) async {
        
    }

    private func handleProjectClear() async {
        guard container.projectVM.isProjectSelected else { return }

        container.conversationVM.setSelectedConversation(nil)
        container.projectVM.clearProject()

        let languagePreference = container.projectVM.languagePreference
        await applyProjectContext(path: nil)

        let clearMessage: String
        switch languagePreference {
        case .chinese:
            clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
        case .english:
            clearMessage = "✅ Project cleared. No project is currently selected."
        }

        let conversationId = container.conversationVM.selectedConversationId ?? UUID()
        container.messagePendingVM.appendMessage(ChatMessage(role: .assistant, conversationId: conversationId, content: clearMessage))
    }

    private func applyProjectContext(path: String?) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }

    private func upsertRootSystemMessage(_ content: String) {
        let currentMessages = container.messagePendingVM.messages
        let conversationId = container.conversationVM.selectedConversationId ?? UUID()
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            container.messagePendingVM.updateMessage(systemMessage, at: 0)
        } else {
            container.messagePendingVM.insertMessage(systemMessage, at: 0)
        }
    }
}
