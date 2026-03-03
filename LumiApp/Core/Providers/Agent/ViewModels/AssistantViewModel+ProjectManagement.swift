import Foundation
import OSLog

extension AssistantViewModel {
    // MARK: - 项目管理

    /// 切换到指定项目
    func switchProject(to path: String) {
        // 使用内核的 AgentProvider 执行实际的项目切换
        AgentProvider.shared.switchProject(to: path)

        // 更新本地状态（镜像 AgentProvider）
        self.currentProjectName = AgentProvider.shared.currentProjectName
        self.currentProjectPath = AgentProvider.shared.currentProjectPath
        self.isProjectSelected = AgentProvider.shared.isProjectSelected
        self.selectedProviderId = AgentProvider.shared.selectedProviderId
        self.selectedModel = AgentProvider.shared.selectedModel

        // 更新 ContextService 并刷新系统提示
        let languagePreference = self.languagePreference

        Task {
            // 刷新系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )

            // 更新第一条系统消息
            if !messages.isEmpty, messages[0].role == .system {
                messages[0] = ChatMessage(role: .system, content: fullSystemPrompt)
            } else {
                messages.insert(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加切换项目通知（根据语言偏好）
            let projectName = AgentProvider.shared.currentProjectName
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

            messages.append(ChatMessage(role: .assistant, content: switchMessage))

            if Self.verbose {
                os_log("\(self.t) 已切换到项目：\(projectName) (\(path))")
            }
        }
    }

    /// 获取最近使用的项目列表（使用 AgentProvider）
    func getRecentProjects() -> [RecentProject] {
        return AgentProvider.shared.getRecentProjects()
    }
}
