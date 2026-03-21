import SwiftUI

extension RootView {
    @MainActor
    func onProjectContextRequestChanged() {
        guard let request = container.projectContextRequestVM.request else { return }

        switch request {
        case let .switchProject(path):
            Task {
                await handleProjectSwitch(path: path)
                container.projectContextRequestVM.request = nil
            }

        case .clearProject:
            Task {
                await handleProjectClear()
                container.projectContextRequestVM.request = nil
            }
        }
    }

    private func handleProjectSwitch(path: String) async {
        container.ProjectVM.switchProject(to: path)
        let languagePreference = container.ProjectVM.languagePreference
        await applyProjectContext(path: path, languagePreference: languagePreference)

        let projectName = container.ProjectVM.currentProjectName
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

        container.messageViewModel.appendMessage(ChatMessage(role: .assistant, content: switchMessage))
    }

    private func handleProjectClear() async {
        guard container.ProjectVM.isProjectSelected else { return }

        container.ConversationVM.setSelectedConversation(nil)
        container.ProjectVM.clearProject()

        let languagePreference = container.ProjectVM.languagePreference
        await applyProjectContext(path: nil, languagePreference: languagePreference)

        let clearMessage: String
        switch languagePreference {
        case .chinese:
            clearMessage = "✅ 已取消选择项目，当前未关联任何项目。"
        case .english:
            clearMessage = "✅ Project cleared. No project is currently selected."
        }

        container.messageViewModel.appendMessage(ChatMessage(role: .assistant, content: clearMessage))
    }

    private func applyProjectContext(path: String?, languagePreference: LanguagePreference) async {
        let fullSystemPrompt = await container.promptService.buildSystemPrompt(
            languagePreference: languagePreference,
            includeContext: true
        )
        upsertRootSystemMessage(fullSystemPrompt)
        await container.slashCommandService.setCurrentProjectPath(path)
    }
}
