import Foundation
import MagicKit

/// 项目上下文与 Root 系统提示词联动
///
/// 每个窗口拥有独立的 ProjectController 实例，通过 WindowScope 直接访问窗口级 VM。
@MainActor
final class ProjectController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false

    private let scope: WindowScope
    private let global: RootContainer

    init(scope: WindowScope, global: RootContainer) {
        self.scope = scope
        self.global = global
    }

    /// 响应 `WindowProjectContextRequestVM` 的请求
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
        let fullSystemPrompt = await global.promptService.buildSystemPrompt(
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await global.slashCommandService.setCurrentProjectPath(path)
    }

    private func handleProjectSwitch(path: String) async {

    }

    private func handleProjectClear() async {
        guard scope.projectVM.isProjectSelected else { return }

        scope.conversationVM.setSelectedConversation(nil)
        scope.projectVM.clearProject()

        let languagePreference = scope.projectVM.languagePreference
        await applyProjectContext(path: nil)

        let clearMessage: String
        switch languagePreference {
        case .chinese:
            clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
        case .english:
            clearMessage = "✅ Project cleared. No project is currently selected."
        }

        let conversationId = scope.conversationVM.selectedConversationId ?? UUID()
        scope.messagePendingVM.appendMessage(ChatMessage(role: .assistant, conversationId: conversationId, content: clearMessage))
    }

    private func applyProjectContext(path: String?) async {
        let fullSystemPrompt = await global.promptService.buildSystemPrompt(
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await global.slashCommandService.setCurrentProjectPath(path)
    }

    private func upsertRootSystemMessage(_ content: String) {
        let currentMessages = scope.messagePendingVM.messages
        let conversationId = scope.conversationVM.selectedConversationId ?? UUID()
        let systemMessage = ChatMessage(role: .system, conversationId: conversationId, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            scope.messagePendingVM.updateMessage(systemMessage, at: 0)
        } else {
            scope.messagePendingVM.insertMessage(systemMessage, at: 0)
        }
    }
}
